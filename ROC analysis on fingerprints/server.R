library(ggplot2)
library(class)
library(ROCR)
library(shiny)

shinyServer(function(input,output){
  
  output$plot <- renderPlot({
    recog_sd = as.numeric(input$recog_sd)
    number_of_people = round(as.numeric(input$number_of_people))
    number_of_minutiae = round(as.numeric(input$number_of_minutiae))
    n_tests = 200
    
    # parameters for finger distribution
    # all units are in mm
    fp_shape = 0.193
    fp_scale = 0.591
    fp_rate= 1/fp_scale
    iterations = 1
   
    # Here are scripts
    
    df_centers <- data.frame()
    generate_minutiae <- function(df_centers){
      new_distance = rgamma(1,fp_shape,rate=fp_rate)
      angle = runif(1,0,2*pi)
      new_x = new_distance*cos(angle)+0.5
      new_y = new_distance*sin(angle)+0.7
      return(c(new_x,new_y))
    }
    
    for (i in 1:number_of_minutiae){
      new_minutiae = generate_minutiae()
      df_centers <- rbind(df_centers,new_minutiae)
    }
    
    
    
    # functions
    generate_point<- function(p,sd=recog_sd){
      #   new_distance = rgamma(1,shape = fp_shape,rate = fp_shape)
      #   angle = runif(1,0,2*pi)
      #   new_x = p[1]+cos(angle)*new_distance
      #   new_y = p[1]+sin(angle)*new_distance
      angle = runif(1,0,2*pi)
      new_dist = rnorm(1,mean = 0,sd =sd)
      new_x = p[1] + sin(angle)*new_dist
      new_y =  p[2] + cos(angle)*new_dist
      return(c(new_x,new_y))
    }
    
    generate_group <- function(c,n=iterations,group_id,sd=recog_sd){
      i=1
      df_p = data.frame()
      while (i <=n){
        new_point <- generate_point(c,sd)
        # g <- g+geom_point(data = as.data.frame(new_point), aes(x = new_point[1], y= new_point[2]))
        df_p <- rbind(df_p,new_point)
        i=i+1
      }
      df_p['id'] <- group_id
      names(df_p) <- c('x','y')
      return(df_p)
    }
    
    # scripts 
    g <- ggplot()   # create ggplot for plottting 
    # this function generate all possible finger print scan of same person
    generate_identicals <- function(df_centers){
      df_groups = data.frame()
      for (i in 1:nrow(df_centers)){
        temp_c = df_centers[i,]
        group = generate_group(temp_c,group_id = i)
        df_groups = rbind(df_groups,group)
      }
      names(df_groups) <- c('x','y','id')
      df_groups$id = as.factor(df_groups$id)
      g = g + geom_point(data = df_groups, aes(x=df_groups$x, y=df_groups$y, color=df_groups$id))
      return(df_groups)
    }
    
    
    ### generate different people's minutea points
    
    generate_center <- function(center,c_id){
      # new_distance = rgamma(1,shape = fp_shape,rate = fp_rate)
      new_distance = runif(1,min = 0,0.15)
      angle = runif(1,0,2*pi)
      new_x = center[1] + cos(angle)*new_distance
      new_y = center[2] + sin(angle)*new_distance
      return(c(new_x,new_y,c_id))
    }
    
    df_all_centers <- data.frame()
    df_lines <- data.frame()
    for (i in 1:number_of_people){
      df_individual_centers = data.frame()
      for (j in 1:nrow(df_centers)){
        tem = generate_center(df_centers[j,],j)
        df_individual_centers = rbind(df_individual_centers,unlist(tem))
      }
      names(df_individual_centers) <- c('x','y','c_id')
      df_individual_centers$person_id = rep(i,nrow(df_individual_centers))
      df_all_centers <- rbind(df_all_centers,df_individual_centers)
      names(df_all_centers) <-  c('x','y','c_id','person_id')
      #construct df for drawing lines
      permutations <- combn(nrow(df_centers),2)
      for(k in 1:ncol(permutations)){
        perv_vec = permutations[,k]
        df_ends = df_individual_centers[perv_vec,]
        df_lines = rbind(df_lines, df_ends)
        #gg <- gg+geom_segment(data = df_ends,aes(x=df_ends$x[1],y=df_ends$y[1],xend=df_ends$x[2],yend=df_ends$y[2]))
      }
    }
    # fac <- as.factor(paste(df_lines$c_id,df_lines$person_id))
    persons <- as.factor(df_lines$person_id)
    fac <- as.factor(rep(1:(nrow(df_lines)/2),each=2))
    ggg <- ggplot(data=df_lines,aes(x=df_lines$x,y=df_lines$y))+geom_line(aes(color=persons,group=fac))+geom_point(aes(color=persons))
    ggg <- ggg+theme_bw()+ggtitle("Gammaly distributed minutiae points")+xlab("x-axis")+ylab('y-axis')
    # this plot shows people's minutiae points
    
    
    # function to generate random scanning for test
    generate_fp <- function(df_all_centers){
      p_id = sample(1:number_of_people,1)
      df_center_to_test <- df_all_centers[df_all_centers$person_id==p_id,]
      df_fp = generate_identicals(df_center_to_test)
      df_fp['person_id'] = rep(p_id, nrow(df_center_to_test))
      return(df_fp)
    }
    
    # testing
    predictions<-c()
    for(j in 1:n_tests){
      df_test =  generate_fp(df_all_centers)
      test <-df_test[,c('x','y'),]
      true_response <- paste(df_test$id,df_test$person_id,sep = ',')
      train <- df_all_centers[,c('x','y')]
      train_response =paste(df_all_centers$c_id,df_all_centers$person_id,sep = ',')
      pred <- knn(train,test = test,cl = train_response,k=1)
      
      ids <- c()
      for(i in 1:length(pred)){
        pred_split <- strsplit(toString(pred[i]),',')
        possible_id <- as.numeric(unlist(pred_split)[2])
        ids<-c(ids,possible_id)
      }
      pred_prob <- sum(ids==unique(df_test$person_id))/(length(ids))
      predictions <- c(predictions,pred_prob)
    }
    
    labels = c(rep(1,n_tests),rep(0,n_tests))
    predictions <- c(predictions,(1-predictions))
    pred <- prediction(predictions,labels)
    perf <- performance(pred,measure =  "tpr",x.measure = "fpr")
    false_rate = sum(predictions[1:(length(predictions)/2)]<0.5)/n_tests
    plot(perf,main = paste("Roc Curve of",number_of_people,'people with recognizing sd =',recog_sd,'\n False rate being:',false_rate))
    abline(a=0,b=1)
    
  })
  
})