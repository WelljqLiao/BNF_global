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

FNF_data <- read.csv("1_Data/FNFdata_extract.csv")

##1.1缺失值处理----
# missForest填充缺失值
library(missForest)
library(doParallel)
registerDoParallel(cores = 4)

set.seed(101)
fnf_result <- missForest(
  xmis = FNF_data[, 5:40],
  ntree = 1000,
  verbose = T,
  parallelize = "forest"
)

FNF_data[,5:40] <- fnf_result$ximp
plot_missing(FNF_data)

options(na.action = "na.fail")
FNF_data <- na.omit(FNF_data[5:40])

library(caret)
library(randomForest)
boston <- FNF_data

seed_range <- 61

set.seed(seed_range)

trains <- createDataPartition( 
  y = boston$lnBNF, 
  p = 0.80, 
  list = F,
  times = 1
)

data_train <- boston[trains, ] #80%
data_test <- boston[-trains, ]  #20%

colnames(boston)
data_trainx <- data_train[, 1:35]
data_trainy <- data_train$lnBNF

data_testx <- data_test[, 1:35]
data_testy <- data_test$lnBNF

set.seed(61)
  fit_rf <- randomForest(
    x = data_trainx,
    y = data_trainy,
    ntree = 50, 
    mtry = 5, 
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
    geom_smooth(method = "loess",se = TRUE, col = "blue") +
    scale_color_viridis(option = "D") +
    labs(x = feature_names[i], y = "Shapley Value")+
    theme(axis.text.x = element_text(angle = 45, hjust = 1))
  plots[[i]] <- p
}

combined_plots <- do.call(arrangeGrob, c(plots, ncol = 7))
title <- ggplot() + 
  ggtitle("FNF Shapley Value Plot") + 
  theme(plot.title = element_text(hjust = 0.05))

grid.arrange(title, combined_plots, heights = c(1, 25))

