require(randomForest)
#se carga la base de datos
bc_data <- read.table("wpbc.data", header = FALSE, sep = ",")

colnames(bc_data) = c("id", "c", "t","r1", "t1", "p1", "a1", "su1",
                      "com1", "con1", "pc1", "si1", "df1",
                      "r2", "t2", "p2", "a2", "su2",
                      "com2", "con2", "pc2", "si2", "df2",
                      "r3", "t3", "p3", "a3", "su3",
                      "com3", "con3", "pc3", "si3", "df3",
                      "tt", "eg")

#se eliminan registros con error
error = bc_data$eg == '?'
bc_data = bc_data[!error,]

#se modifica la ultima variable a numerica
bc_data$eg = as.numeric(bc_data$eg)

#eliminar variables que son necesarias
bc_data$id = NULL
bc_data$t = NULL

library(foreach)

range01 <- function(x){(x-min(x))/(max(x)-min(x))}

foreach(i=2:33) %dopar% {
  #se seta la semilla
  bc_data[i] = range01(bc_data[i])
}


#generar curva ROC
n = 300
n2 = 2
n2_original = 2

curva_roc = data.frame(ntree = numeric() ,ntry = numeric(), especificidad = numeric(), sensibilidad = numeric(), euclidiana = numeric())

foreach(i=1:(171*30)) %dopar% {
  #se seta la semilla
  set.seed(21)
  modelo = randomForest(c~ ., data=bc_data, ntree = n, importance=TRUE, proximity=TRUE, ntry=n2)
  vp = modelo$confusion[1,1]
  vn = modelo$confusion[1,2]
  fn = modelo$confusion[2,1]
  fp = modelo$confusion[2,2]
  esp = (1-(vn/(fp+vn)))
  sen = (vp/(vp+fn))
  curva_roc = rbind(curva_roc, data.frame(ntree = n, ntry = n2, especificidad = esp, sensibilidad = sen, euclidiana = sqrt(((1-sen)^2) + (esp^2))))
  n2 = n2 + 1
  
  if(n2 == 32){
    n2 = n2_original
    n = n + 10
  }
  print(n)
}


plot(curva_roc$especificidad, curva_roc$sensibilidad, main="Curva ROC", ylab = "sensibilidad", xlab = "1-especificidad")

set.seed(21)
modelo = randomForest(c~ ., data=bc_data, ntree = 610, importance=TRUE, proximity=TRUE, ntry=2)

tabla = modelo$importance
varImpPlot(modelo)

# Type of random forest: classification
# Number of trees: 610
# No. of variables tried at each split: 5
# 
# OOB estimate of  error rate: 24.23%
# Confusion matrix:
#   N R class.error
# N 145 3  0.02027027
# R  44 2  0.95652174

#eliminar caracteristicas según importancia
#se ordenan según grado de importancia
bc_fn = bc_data[c("c","eg","df1","tt","su3","r2","t2","t1","con2","t3","p2","r3","si2","si1","a3","pc2","com2","df2","p3","com1","con1","a2","su1","a1","df3","con3","pc3","pc1","su2","r1","si3","p1","com3")]

bc_error = data.frame(n_variables=numeric(), error=numeric())

n = 33

for (i in 1:32)
{
  set.seed(21)
  modelo = randomForest(c~ ., data=bc_fn[,1:n], ntree = 610, importance=TRUE, proximity=TRUE, ntry=2)
  vp = modelo$confusion[1,1]
  vn = modelo$confusion[1,2]
  fn = modelo$confusion[2,1]
  fp = modelo$confusion[2,2]
  e = (vn+fn)/(vp+vn+fn+fp)
  bc_error = rbind(bc_error, data.frame(n_variables = n, error = e))
  n = n - 1
}

#se grafica el error
plot(bc_error$n_variables, bc_error$error,  type="overplotted", main="Reducción de variables", ylab = "Error", xlab = "Cantidad de variables")

#obteniendo que con 14 variables obtiene un mejor resultado
set.seed(21)
modelo = randomForest(c~ ., data=bc_fn[,1:10], ntree = 610, importance=TRUE, proximity=TRUE, ntry=2)
# Type of random forest: classification
# Number of trees: 610
# No. of variables tried at each split: 3
# 
# OOB estimate of  error rate: 21.65%
# Confusion matrix:
#   N R class.error
# N 145 3  0.02027027
# R  39 7  0.84782609

plot(modelo)
legend("bottomright", colnames(modelo$err.rate),col=1:4,cex=0.8,fill=1:4)

#MDS
bc.mds = cmdscale(1 - modelo$proximity, eig=TRUE) # escalamiento clásico

op = par(pty="s") # A character specifying the type of plot region to be used; "s"

pairs(cbind(bc_fn[,2:10], bc.mds$points), cex=0.6, gap=0,
      col=c("red", "green")[as.numeric(bc_fn$c)],
      main="Breast Cancer Pronostic Wisconsin")

par(op)

library("MASS")
parcoord(bc_fn[1:50,2:10],var.label = TRUE,col=c("red", "green")[as.numeric(bc_fn$c)])
legend("bottomright",legend = c("N", "R"),fill=2:3)
