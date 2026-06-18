# Chow-Liu tree analysis of audits data
# Identifies dependency structure among categorical variables

# Load packages, installing if needed
required_packages <- c("readr", "dplyr", "igraph", "ggraph", "ggplot2")
for (pkg in required_packages) {
  if (!require(pkg, character.only = TRUE)) {
    install.packages(pkg, repos = "https://cran.r-project.org")
    library(pkg, character.only = TRUE)
  }
}

# Read audit data
audits <- read_delim("input_data/audits.txt", delim = "\t")
cat("Loaded", nrow(audits), "audit records\n\n")

# Step 1: Identify categorical columns (2-19 distinct non-NA values)
col_distinct <- sapply(audits, function(x) n_distinct(x, na.rm = TRUE))
cat_cols <- names(col_distinct)[col_distinct >= 2 & col_distinct <= 50]

cat("Column statistics:\n")
col_summary <- data.frame(
  Column = names(col_distinct),
  Distinct_Values = col_distinct,
  Retained = names(col_distinct) %in% cat_cols
)
print(col_summary)
cat("\nRetained columns:", length(cat_cols), "\n")
cat("Retained:", paste(cat_cols, collapse = ", "), "\n\n")

audits_cat <- audits[, cat_cols, drop = FALSE]

# Step 2: Compute mutual information for all pairs
compute_mi <- function(x, y) {
  # Treat NA as its own category
  x_char <- ifelse(is.na(x), "NA", as.character(x))
  y_char <- ifelse(is.na(y), "NA", as.character(y))

  # Contingency table
  cont <- table(x_char, y_char)
  n_total <- sum(cont)

  # Joint and marginal probabilities
  p_xy <- cont / n_total
  p_x <- rowSums(p_xy)
  p_y <- colSums(p_xy)

  # Mutual information: I(X,Y) = sum p(x,y) * log(p(x,y) / (p(x)*p(y)))
  mi <- 0
  for (i in seq_len(nrow(p_xy))) {
    for (j in seq_len(ncol(p_xy))) {
      if (p_xy[i, j] > 0) {
        mi <- mi + p_xy[i, j] * log(p_xy[i, j] / (p_x[i] * p_y[j]))
      }
    }
  }

  return(max(mi, 0))
}

# Build MI matrix
n_cols <- length(cat_cols)
mi_matrix <- matrix(0, nrow = n_cols, ncol = n_cols)
rownames(mi_matrix) <- cat_cols
colnames(mi_matrix) <- cat_cols

for (i in seq_len(n_cols - 1)) {
  for (j in seq(i + 1, n_cols)) {
    mi_val <- compute_mi(audits_cat[[cat_cols[i]]], audits_cat[[cat_cols[j]]])
    mi_matrix[i, j] <- mi_val
    mi_matrix[j, i] <- mi_val
  }
}

cat("Pairwise Mutual Information Matrix:\n")
print(round(mi_matrix, 4))
cat("\n")

# Step 3: Build maximum spanning tree
g <- graph_from_adjacency_matrix(mi_matrix, mode = "undirected",
                                 weighted = TRUE, diag = FALSE)
tree_undirected <- mst(g, weights = E(g)$weight)

cat("MST edges:\n")
tree_edges <- as_data_frame(tree_undirected, what = "edges")
print(tree_edges)
cat("\n")

# Step 4: Root tree at node with highest marginal entropy
compute_entropy <- function(x) {
  x_char <- ifelse(is.na(x), "NA", as.character(x))
  p <- table(x_char) / length(x_char)
  entropy <- -sum(p * log(p), na.rm = TRUE)
  return(entropy)
}

entropies <- sapply(audits_cat, compute_entropy)
root_node <- cat_cols[which.max(entropies)]

cat("Marginal entropies:\n")
print(round(entropies, 4))
cat("Root node (highest entropy):", root_node, "\n\n")

# Step 5: Convert undirected tree to directed (edges away from root) via BFS
# Build adjacency list from undirected tree
adj_list <- as_adj_list(tree_undirected, mode = "all")
names(adj_list) <- cat_cols

# BFS to orient edges and build parent-child relationships
bfs_queue <- list(root_node)
visited <- setNames(rep(FALSE, n_cols), cat_cols)
visited[root_node] <- TRUE
parent_map <- setNames(rep(NA_character_, n_cols), cat_cols)
children_map <- setNames(vector("list", n_cols), cat_cols)

while (length(bfs_queue) > 0) {
  current <- bfs_queue[[1]]
  bfs_queue <- bfs_queue[-1]

  # Get neighbors
  neighbor_idx <- attr(adj_list[[current]], "names")
  neighbors <- cat_cols[as.numeric(neighbor_idx)]

  for (neighbor in neighbors) {
    if (!visited[neighbor]) {
      visited[neighbor] <- TRUE
      parent_map[neighbor] <- current
      children_map[[current]] <- c(children_map[[current]], neighbor)
      bfs_queue <- c(bfs_queue, neighbor)
    }
  }
}

# Step 6: Compute conditional frequency tables for tree nodes
# Build ancestry chain for each node
get_ancestry <- function(node) {
  chain <- c(node)
  current <- node
  while (!is.na(parent_map[current])) {
    current <- parent_map[current]
    chain <- c(current, chain)
  }
  return(chain)
}

# Compute node data (column, value, count, conditional percentage)
node_list <- list()

for (col_name in cat_cols) {
  ancestry <- get_ancestry(col_name)

  if (is.na(parent_map[col_name])) {
    # Root node: marginal frequencies
    col_vals <- ifelse(is.na(audits_cat[[col_name]]), "NA",
                       as.character(audits_cat[[col_name]]))
    freq_table <- table(col_vals)

    for (val in names(freq_table)) {
      node_list[[length(node_list) + 1]] <- data.frame(
        node_id = paste0(col_name, ".", val),
        column = col_name,
        value = val,
        count = as.integer(freq_table[val]),
        pct_parent = 100.0
      )
    }
  } else {
    # Child node: conditional on parent chain
    temp_df <- audits_cat[, ancestry, drop = FALSE]

    # Convert to characters, treating NA
    for (col in ancestry) {
      temp_df[[col]] <- ifelse(is.na(temp_df[[col]]), "NA",
                               as.character(temp_df[[col]]))
    }

    # Group by full ancestry and count
    parent_cols <- ancestry[-length(ancestry)]

    freq_table <- temp_df %>%
      group_by(across(all_of(parent_cols))) %>%
      mutate(parent_count = n()) %>%
      ungroup() %>%
      group_by(across(all_of(ancestry))) %>%
      summarise(child_count = n(),
                parent_count = first(parent_count),
                .groups = "drop")

    for (i in seq_len(nrow(freq_table))) {
      val <- freq_table[[col_name]][i]
      node_list[[length(node_list) + 1]] <- data.frame(
        node_id = paste0(col_name, ".", val),
        column = col_name,
        value = val,
        count = freq_table$child_count[i],
        pct_parent = 100 * freq_table$child_count[i] / freq_table$parent_count[i]
      )
    }
  }
}

node_df <- do.call(rbind, node_list)
rownames(node_df) <- NULL

cat("Node Data (column, value, count, conditional %):\n")
print(node_df)
cat("\n")

# Step 7: Compute edge data (count and percentage flowing along each branch)
edge_list <- list()

for (parent_col in cat_cols) {
  if (length(children_map[[parent_col]]) > 0) {
    for (child_col in children_map[[parent_col]]) {
      # Get ancestry up to parent
      parent_ancestry <- get_ancestry(parent_col)
      child_ancestry <- get_ancestry(child_col)

      # Build temp data with ancestry
      temp_df <- audits_cat[, c(parent_ancestry, child_col), drop = FALSE]
      for (col in names(temp_df)) {
        temp_df[[col]] <- ifelse(is.na(temp_df[[col]]), "NA",
                                 as.character(temp_df[[col]]))
      }

      # Count all combinations along this edge
      edge_counts <- temp_df %>%
        group_by(across(all_of(c(parent_ancestry, child_col)))) %>%
        summarise(count = n(), .groups = "drop")

      # Sum over parent_col to get edge totals
      parent_col_idx <- which(names(edge_counts) == parent_col)
      parent_ancestry_cols <- parent_ancestry[parent_ancestry != parent_col]

      if (length(parent_ancestry_cols) > 0) {
        edge_totals <- edge_counts %>%
          group_by(across(all_of(parent_ancestry_cols))) %>%
          summarise(total = sum(count), .groups = "drop")
      } else {
        edge_totals <- data.frame(total = nrow(audits_cat))
      }

      # Join to get percentages
      edge_summary <- edge_counts %>%
        group_by(across(all_of(parent_ancestry_cols))) %>%
        mutate(pct = 100 * count / sum(count)) %>%
        ungroup()

      for (i in seq_len(nrow(edge_summary))) {
        parent_val <- edge_summary[[parent_col]][i]
        child_val <- edge_summary[[child_col]][i]
        count <- edge_summary$count[i]
        pct <- edge_summary$pct[i]

        edge_list[[length(edge_list) + 1]] <- data.frame(
          from = paste0(parent_col, ".", parent_val),
          to = paste0(child_col, ".", child_val),
          count = count,
          pct = pct
        )
      }
    }
  }
}

edge_df <- do.call(rbind, edge_list)
rownames(edge_df) <- NULL

cat("Edge Data (from, to, count, % of parent):\n")
print(edge_df)
cat("\n")

# Step 8: Build igraph object with node/edge attributes for plotting
# Create vertices from node_df
vertices <- node_df %>%
  select(node_id, column, value, count, pct_parent) %>%
  as.data.frame()

# Create edges from edge_df
edges <- edge_df %>%
  select(from, to) %>%
  as.data.frame()

# Create graph
tree_directed <- graph_from_data_frame(edges, directed = TRUE,
                                       vertices = vertices)

# Step 9: Create tree plot with ggraph
# Calculate node size based on frequency
V(tree_directed)$size <- log(V(tree_directed)$count + 1)
V(tree_directed)$label <- paste0(V(tree_directed)$column, "\n",
                                 V(tree_directed)$value)

# Edge labels: count and percentage
E(tree_directed)$label <- paste0(edge_df$count, "\n(",
                                 round(edge_df$pct, 1), "%)")

# Determine plot size based on node count
n_nodes <- nrow(node_df)
height <- max(10, 4 + 0.5 * n_nodes)
width <- max(16, 8 + 0.3 * n_nodes)

# Create plot
p <- ggraph(tree_directed, layout = "tree", direction = "LR") +
  geom_edge_link(aes(label = label),
                 angle_calc = "along",
                 label_dodge = unit(2.5, "mm"),
                 arrow = arrow(length = unit(2, "mm"), type = "closed"),
                 end_cap = circle(3, "mm"),
                 start_cap = circle(3, "mm")) +
  geom_node_point(aes(size = size), color = "steelblue") +
  geom_node_text(aes(label = label),
                 repel = TRUE,
                 size = 2.5) +
  scale_size_continuous(range = c(1, 6), guide = "none") +
  theme_graph() +
  theme(plot.title = element_text(hjust = 0.5))

# Save plot
png("audits_tree.png", width = width, height = height, units = "in", res = 300)
print(p)
dev.off()

cat("Plot saved to audits_tree.png (", width, "x", height,
    " inches at 300 dpi)\n", sep = "")
