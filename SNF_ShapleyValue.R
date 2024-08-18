library(readr)
library(grid)
library(ggplot2)
library(ggpubr)
library(ggprism)
library(reshape)
library(tidyverse)
library(leaps)
library(rasterVis)
library(raster)
library(viridis) 
library(xgboost)
library(skimr)
library(DataExplorer)
library(caret)
library(pROC)
library(DALEX)
library(iml)
windowsFonts(Font = windowsFont("Times New Roman"))
par(family = 'Font')

SNF_data <- read.csv("data.csv")

library(missForest)
plot_missing(SNF_data)

data_filled <- SNF_data
for (i in 1:ncol(data_filled)) {
  data_filled[is.na(data_filled[, i]), i] <- mean(data_filled[, i], na.rm = TRUE)
}
plot_missing(data_filled)

options(na.action = "na.fail")
SNF_data <- na.omit(data_filled[5:40])

library(caret)
library(randomForest)
boston <- SNF_data

set.seed(843)
trains <- createDataPartition( 
  y = boston$lnBNF, 
  p = 0.80, 
  list = F,
  times = 1
)
data_train <- boston[trains, ] #80%
data_test <- boston[-trains, ] #20%

colnames(boston)
data_trainx <- data_train[, 1:35]
data_trainy <- data_train$lnBNF

data_testx <- data_test[, 1:35]
data_testy <- data_test$lnBNF

set.seed(843)
  fit_rf <- randomForest(
    x = data_trainx,
    y = data_trainy,
    ntree = 50, 
    mtry = 3, 
    importance = TRUE
  )
  
importance_values <- importance(fit_rf)
  
print(importance_values)
varImpPlot(fit_rf)

predictor_rf <- Predictor$new(
  model = fit_rf,
  data = data_trainx,
  y = data_trainy
)

shapley_rf <- Shapley$new(predictor_rf, x.interest = data_trainx[1, ])

shapley_values <- lapply(1:nrow(data_trainx), function(i) {
  Shapley$new(predictor_rf, x.interest = data_trainx[i, ])
})

shapley_matrix <- do.call(rbind, lapply(shapley_values, function(shap) {
  shap$results$phi
}))

shapley_df <- as.data.frame(shapley_matrix)
feature_names <- colnames(data_trainx)
colnames(shapley_df) <- feature_names

library(gridExtra)
plots <- list()
for (i in 1:35) {
  p <- ggplot(data = data.frame(x = data_trainx[, i], y = shapley_matrix[, i]), aes(x = x, y = y)) +
    geom_point() +
    scale_color_viridis(option = "D") +
    geom_smooth(method = "loess",se = TRUE, col = "blue") +
    labs(x = feature_names[i], y = "Shapley Value")+
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  plots[[i]] <- p
}

combined_plots <- do.call(arrangeGrob, c(plots, ncol = 7))
title <- ggplot() + 
  ggtitle("SNF Shapley Value Plot") + 
  theme(plot.title = element_text(hjust = 0.05))

grid.arrange(title, combined_plots, heights = c(1, 25))
