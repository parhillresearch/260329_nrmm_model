#!/usr/bin/env Rscript

# Chow-Liu tree analysis: categorical column dependency structure
# Reads audit data, builds maximum-weight spanning tree of column dependencies,
# traverses as rooted tree, and visualizes with conditional frequency edges

library(readr)
library(dplyr)
library(igraph)
library(ggraph)
library(ggplot2)

# ===== INPUT =====
cat("Reading input files...\n")
audits <- read_delim("input_data/audits.txt", delim = "\t", show_col_types = FALSE)
categories <- readLines("categories.txt") %>% trimws() %>% {.[. != ""]}

# Verify all categories exist in audits
missing <- setdiff(categories, names(audits))
if (length(missing) > 0) {
  stop("ERROR: Missing columns in audits.txt: ", paste(missing, collapse = ", "))
}

# Retain only categorical columns and convert to character (NA -> "NA")
audits_cat <- audits[, categories] %>%
  mutate(across(everything(), ~ ifelse(is.na(.), "NA", as.character(.))))

n_cols <- length(categories)
cat("Loaded", nrow(audits), "rows and", n_cols, "categorical columns\n\n")

# ===== COMPUTE PAIRWISE MUTUAL INFORMATION =====
cat("Computing pairwise mutual information...\n")

compute_mi <- function(x, y) {
  # MI(X,Y) = sum p(x,y) * log(p(x,y) / (p(x) * p(y)))
  tab <- table(x, y)
  p_xy <- tab / sum(tab)
  p_x <- rowSums(p_xy)
  p_y <- colSums(p_xy)

  mi <- 0
  for (i in seq_len(nrow(p_xy))) {
    for (j in seq_len(ncol(p_xy))) {
      if (p_xy[i, j] > 0) {
        mi <- mi + p_xy[i, j] * log(p_xy[i, j] / (p_x[i] * p_y[j]))
      }
    }
  }
  mi
}

mi_matrix <- matrix(0, nrow = n_cols, ncol = n_cols,
                    dimnames = list(categories, categories))

for (i in 1:n_cols) {
  for (j in (i + 1):n_cols) {
    mi <- compute_mi(audits_cat[[categories[i]]], audits_cat[[categories[j]]])
    mi_matrix[i, j] <- mi
    mi_matrix[j, i] <- mi
  }
}

cat("Pairwise Mutual Information Matrix:\n")
print(round(mi_matrix, 4))
cat("\n")

# ===== BUILD MAXIMUM-WEIGHT SPANNING TREE =====
cat("Building maximum-weight spanning tree...\n")

# Create undirected weighted graph
adj_matrix <- mi_matrix
diag(adj_matrix) <- 0

g <- graph_from_adjacency_matrix(adj_matrix, mode = "undirected", weighted = TRUE)
mst <- mst(g, weights = E(g)$weight)

# Get adjacency list
adj_list <- as_adj_list(mst)
names(adj_list) <- categories

cat("MST edges:\n")
mst_edges <- as_data_frame(mst)
for (i in seq_len(nrow(mst_edges))) {
  cat(sprintf("  %s -- %s (MI = %.4f)\n",
              mst_edges$from[i], mst_edges$to[i], mst_edges$weight[i]))
}
cat("\n")

# ===== ROOT THE TREE AT HIGHEST ENTROPY NODE =====
cat("Finding root node (highest marginal entropy)...\n")

compute_entropy <- function(x) {
  # H(X) = -sum p(x) * log(p(x))
  p <- prop.table(table(x))
  -sum(p * log(p))
}

entropies <- sapply(categories, function(col) compute_entropy(audits_cat[[col]]))
root_col <- categories[which.max(entropies)]

cat("Node entropies:\n")
for (col in categories) {
  cat(sprintf("  %s: %.4f\n", col, entropies[col]))
}
cat(sprintf("\nRoot: %s (entropy = %.4f)\n\n", root_col, entropies[root_col]))

# Root the tree via BFS
parents <- setNames(rep(NA_character_, n_cols), categories)

queue <- root_col
visited <- root_col

while (length(queue) > 0) {
  node <- queue[1]
  queue <- queue[-1]

  neighbors <- names(adj_list[[node]])
  for (neighbor in neighbors) {
    if (!(neighbor %in% visited)) {
      parents[neighbor] <- node
      visited <- c(visited, neighbor)
      queue <- c(queue, neighbor)
    }
  }
}

# ===== TRAVERSE ROOTED TREE AND BUILD NODES/EDGES =====
cat("Traversing tree and computing conditional frequencies...\n\n")

all_nodes <- list()
all_edges <- list()
node_id_counter <- 0
node_key_map <- new.env(hash = TRUE)

# Helper: get node ID from (column, value) key
get_node_id <- function(col, val) {
  key <- paste0(col, "|||", val)
  if (exists(key, envir = node_key_map, inherits = FALSE)) {
    get(key, envir = node_key_map)
  } else {
    NA_integer_
  }
}

# Helper: set node ID for (column, value) key
set_node_id <- function(col, val, id) {
  key <- paste0(col, "|||", val)
  assign(key, id, envir = node_key_map)
}

# BFS on (column, parent_col, parent_val) tuples
col_queue <- list(list(col = root_col, parent_col = NA_character_, parent_val = NA_character_))

while (length(col_queue) > 0) {
  current <- col_queue[[1]]
  col_queue <- col_queue[-1]

  col <- current$col
  parent_col <- current$parent_col
  parent_val <- current$parent_val

  # Filter data by parent condition
  if (is.na(parent_col)) {
    df <- audits_cat
  } else {
    df <- audits_cat %>% filter(.data[[parent_col]] == parent_val)
  }

  # Get unique values of current column in filtered data
  col_vals <- unique(df[[col]])

  for (val in col_vals) {
    node_id_counter <<- node_id_counter + 1
    node_id <- node_id_counter
    set_node_id(col, val, node_id)

    # Filter data for this (column, value) pair
    df_node <- df %>% filter(.data[[col]] == val)
    node_count <- nrow(df_node)

    # Create node
    all_nodes[[node_id]] <- data.frame(
      id = node_id,
      label = paste0(col, "\n", val),
      stringsAsFactors = FALSE
    )

    # Find child columns and add edges
    for (child_col in names(adj_list[[col]])) {
      if (!is.na(parents[child_col]) && parents[child_col] == col) {
        # This is a child column in the rooted tree

        # Get unique values of child column in current node's data
        child_vals <- unique(df_node[[child_col]])

        for (child_val in child_vals) {
          # Count rows with this child value
          child_count <- sum(df_node[[child_col]] == child_val)
          pct <- if (node_count > 0) 100 * child_count / node_count else 0

          # Store edge (to_id will be filled in during finalization)
          all_edges[[length(all_edges) + 1]] <- list(
            from_id = node_id,
            child_col = child_col,
            child_val = child_val,
            count = child_count,
            pct = pct
          )
        }

        # Add child column to queue for next iteration
        col_queue[[length(col_queue) + 1]] <- list(
          col = child_col,
          parent_col = col,
          parent_val = val
        )
      }
    }
  }
}

# ===== FINALIZE EDGES (ASSIGN TO_ID) =====
edges_final <- list()
for (edge in all_edges) {
  to_id <- get_node_id(edge$child_col, edge$child_val)
  if (!is.na(to_id)) {
    edges_final[[length(edges_final) + 1]] <- data.frame(
      from = edge$from_id,
      to = to_id,
      label = paste0(edge$count, "\n(", round(edge$pct, 1), "%)"),
      stringsAsFactors = FALSE
    )
  }
}

nodes_df <- do.call(rbind, all_nodes)
rownames(nodes_df) <- NULL

edges_df <- do.call(rbind, edges_final)
rownames(edges_df) <- NULL

# ===== PRINT SUMMARY =====
cat("Node/Edge Summary:\n")
cat("Number of nodes:", nrow(nodes_df), "\n")
cat("Number of edges:", nrow(edges_df), "\n\n")

cat("Nodes (first 30):\n")
print(head(nodes_df, 30))
cat("\nEdges (first 30):\n")
print(head(edges_df, 30))
cat("\n")

# ===== CREATE TREE PLOT =====
cat("Creating tree plot...\n")

# Build igraph from edges and vertices
g_plot <- graph_from_data_frame(
  edges_df[, c("from", "to")],
  directed = TRUE,
  vertices = nodes_df
)

# Set vertex labels
V(g_plot)$label <- nodes_df$label

# Create plot with ggraph
p <- ggraph(g_plot, layout = "tree", direction = "LR") +
  geom_edge_link(
    aes(label = label),
    arrow = arrow(length = unit(0.2, 'cm'), type = 'closed'),
    angle_calc = 'along',
    label_dodge = unit(2, 'mm'),
    label_size = 3
  ) +
  geom_node_point(size = 3, color = "steelblue") +
  geom_node_text(aes(label = label), repel = TRUE, size = 3) +
  theme_graph()

ggsave("audits_tree.png", p, width = 20, height = 16, dpi = 300, units = "in")

cat("Tree plot saved to audits_tree.png (20 x 16 inches, 300 dpi)\n")
