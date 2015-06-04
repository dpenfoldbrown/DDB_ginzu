"uinit" <-
function () {
	library(RMySQL)
	con<-MySQL(fetch.default.rec = 5000000 )
	dbh <- dbConnect( con )
	dbh
}
"getTableDF" <-
function( dbh = stop("Needs dbh"), database = stop("Needs database"), tablename = stop("Needs tablename") ) {
	statement <- paste("SELECT * FROM ",database,".",tablename)
	print(statement)
	rs <- dbSendQuery(dbh, statement)
	df <- fetch(rs, -1 )
	names(df) <- gsub("_","",names(df))
	df
}
"scatterFactor" <- # scatter plot with colors depending on factor
function ( x = x, y = y, factor = factor, ... ) {
	plot(x,y,type="n",...) # make empty plot
	color <- rainbow(length(unique(factor)))
	count <- 1
	for (i in unique(factor)) { # over factor
		#lines(x[factor == i], y[factor == i],col=color[count]) # make points
		points(x[factor == i], y[factor == i],col=color[count]) # make points
		count <- count+1 # increment
	}
}
"phexbin" <-
function (...) {
	plot(hexbin(...),style='colorscale',colramp=function(n){ topo.colors(n) })
	# nested.centroids
	# centroids
	# lattice
	# colorscale
	# nested.lattice
}
"mbarplot" <-
function (x=x,nrow=2,...) {
	barplot(matrix(as.numeric(x),nrow=nrow),col=rainbow(nrow),col=col,...)
	#barplot(matrix(c(91,5,2,16,6,18,5,16),ncol=4),col=rainbow(3))
}
"heatmapp" <-
function (df=df) {
	heatmap(as.matrix(df))
}
"histt" <-
function(x=x,...) {
	hist(as.numeric(x),...);
}
"parr" <- function (x=x,y=y) {
	par(mfrow=c(y,x))
}
"barplott" <-
function (height=height,std=std,...) {
	mp <- barplot(height=as.numeric(height),ylim=c(0,max(as.numeric(height))*1.10),...);
	arrows(mp, as.numeric(height)-as.numeric(std), mp, as.numeric(height)+as.numeric(std), code=3, angle=90, length=0.1)
}
"lala" <-
function (...) {
	c(1,2,3);
}
"dens" <- # density plots with factor
function ( data = data, factor = factor, ... ) {
	color <- rainbow(length(unique(factor)))
	max <- 0
	df <- as.data.frame(unique(factor))
	names(df) <- c('factor')
	for (i in unique(factor)) {
		d <- density(x=as.numeric(data[factor == i]),bw="sj")
		df$density[df$factor == i] <- d
		max <- max(max,max(d$y))
	}
	dall <- density(x=as.numeric(data),bw="sj")
	max <- max(max,max(dall$y))
	plot(dall,ylim=c(0,max),type="l",col="black",lwd=par()$lwd+2,...)
	count <- 0
	for (i in unique(factor)) {
		count <- count+1
		#lines(df$density[df$factor==i],type="l",col=color[count])
		lines(density(x=as.numeric(data[factor == i]),bw="sj"),type="l",col=color[count])
	}
	legend(x = 'topright', legend = c('all',unique(factor)), col = c('black',color), lwd = 4 )
}
"roc" <- # takes a df and makes roc-plot with mult.lines. LOTS OF STUFF HARD-CODED. Modify DDB::PAGE->resultPlot() to get cols right
function ( df = stop("needs data frame"),fct=stop("needs fct"),pcols=stop("needs pcols"),step=100,n=1,xmax=1,ymax=1,...) {
	#"roc( df, fct='c1', pcols=c('%s'), xlab='1-specificity',ylab='sensitivity' )", join "','", @{ $data{a1} } );
	#"roc( df, fct='c1', pcols=c('%s'), xlab='1-specificity',ylab='sensitivity',xmax=0.01,ymax=0.5 )", join "','", @{ $data{a1} } );
	x <- 1:step
	y <- 1:step
	plot(x~y,type="n",xlim=c(0,xmax),ylim=c(0,ymax),...)
	colors <- rainbow(length(pcols)) # nice colors
	count <- 0
	for (i in pcols) {
		count <- count+1
		rocline( df[,fct],df[,i],step=step,col=colors[count] )
	}
	legend(.70,.6,pcols,col=colors[1:count],pch="l")
}
"rocline" <-
function ( fct = stop("needs factor"), probability = spot("needs probability"),step=100,col="red")
{
	x <- array(0:step)
	y <- array(0:step)
	for (i in 0:step) {
		cutoff <- 1-(i/step)
		ret <- senspec(fct = fct,probability = probability, cutoff = cutoff)
		y[i] <- ret[1]
		x[i] <- 1-ret[2]
	}
	lines(x,y,col=col)
}
"senspec" <-
function( fct = stop("needs factor"), probability = stop("needs probability"),cutoff=stop("needs cutoff"))
{
	tp <- length(fct[ probability >= cutoff & fct == 1])
	fn <- length(fct[ probability < cutoff & fct == 1])
	tn <- length(fct[ probability < cutoff & fct == 0])
	fp <- length(fct[ probability >= cutoff & fct == 0])
	c(tp/(tp+fn),tn/(tn+fp))
}
"hist2d" <-
function (c1,c2,fac,nr=8,type="diff",...)
{
	par(ask=FALSE)
	s1 <- pretty(c1,nr)
	s2 <- pretty(c2,nr)
	tab <- table(cut(c1,s1),cut(c2,s2))
	if (type == 'all') {
		foof.image(tab,main="All",...)
	} else {
		tabC <- table(cut(c1[fac == 'yes' | fac == 1],s1),cut(c2[fac == 'yes' | fac == 1],s2))
		tabI <- table(cut(c1[fac == 'no' | fac == 0],s1),cut(c2[fac == 'no' | fac == 0],s2))
		tabDiv <- tabC/tab
		tabDiv <- round(tabDiv * 100,0 )
		if (type == 'correct') {
			foof.image(tabC,main="Correct",...)
		}
		if (type == 'incorrect') {
			foof.image(tabI,main="Incorrect",...)
		}
		if (type == 'diff') {
			foof.image(tabDiv,main="Percentage correct",...)
		}
	}
}
"linehistmf" <-
function (var=var,def=def,breaks='scott',lwd=4,includeAll=FALSE,...)
{
	var <- as.numeric(var)
	histt <- hist(var,breaks=breaks,plot=includeAll) # defined break points
	uniq <- unique(def)
	col <- rainbow(length(uniq)) # nice colors
	maxy = 0
	maxx = 0
	for (i in 1:length(uniq)) {
		if (i == 1) { # the first pass, plot the actual histogram. Also print the line for this guy
			histog <- hist(var[def == uniq[i]],breaks=histt$breaks,border=col[i],plot=!includeAll,ylim=c(0,max(histt$counts)),...)
		}
		histog <- hist(var[def == uniq[i]],breaks=histt$breaks,plot=FALSE) # dont plot histogram
		maxx =max(histog$mids,maxx) # legend placement
		maxy =max(histog$counts,maxy) # legend placement
		nb <- rep(histog$breaks,each=2)[2:(length(histog$breaks)*2-1)]
		nc <- rep(histog$counts,each=2)
		#lines(nb,nc,col=col[i],lwd=1) # plot line
		#print(paste('nb',nb))
		#print(paste('nc',nc))
		lines(histog$mids,histog$counts,col=col[i],lwd=lwd) # plot line
	}
	#lines(c(0,500,500,1000,1000,1500),c(50,50,1000,1000,500,500))
	legend(maxx*0.8, maxy,lwd=lwd, legend = uniq, col = col) # put the legend
}
"linehist" <-
function (var=var,def=def,breaks='scott',lwd=4,y2lab="ratio",ylim="max",vlines=FALSE,...)
{
	#str(var)
	var <- as.numeric(var)
	hist <- hist(var,breaks=breaks,plot=FALSE) # defined break points
	histno <- hist(var[def == 'no' | def == 0],breaks=hist$breaks,plot=FALSE) # incorrect
	histyes <- hist(var[def == 'yes' | def == 1],breaks=hist$breaks,plot=FALSE) # correct
	max <- max(histyes$counts,histno$count)
	if (ylim == "max") {
		ylim = c(0,max)
	}
	plot(histno$mids,histno$counts,type="l",lwd=lwd,ylim=ylim,...) # plot incorrect
	abline(v=hist$breaks,col='grey') # ablines
	if(vlines) {
		for (br in hist$breaks) {
			abline(v=br,col='#cccccc')
		}
	}
	lines(histno$mids,histno$counts,type="l",lwd=lwd,ylim=ylim,...) # plot incorrect
	par(ann=FALSE) # dont put anything on the labels
	lines(histyes$mids,histyes$counts,col="red",lwd=lwd) # correct line
	par(ann=TRUE) # put things on labels again
	par(new=T,xaxs="r") # plot in existing graph
	# plot blue diff-line
	plot(histno$mids,(histyes$counts/(histno$counts+histyes$counts)),axes=F,ylab="",xlab="",type="l",col="blue",lwd=lwd,ylim=c(0,1))
	# put on right axis
	axis(side=4) # write to right
	mtext(side=4,line=1.8,y2lab,cex=par()$cex) # write to right
	#abline(1,0,lwd=lwd/2)
}
"linehistDiff" <-
function (var,def,...)
{
histno <- hist(var[def == 'no'],plot=FALSE)
histyes <- hist(var[def == 'yes'],plot=FALSE)
#label <- paste( ' Defined by ',names(df[2]),' # ',length(df[,1]))
#if (length(df[3])>0) { label <- paste(label,'(',unique(df[3]),')') }
#xlab <- paste(names(df[1]),
#' no: ',histno$mids[1],
#' - ',histno$mids[length(histno$mids)-1],
#' yes: ',histyes$mids[1],
#' - ',histyes$mids[length(histyes$mids)-1]
#)
xlab = 'x label'
label = 'label'
plot(histno$mids,histno$counts,type="l",main=label,xlab=xlab,...)
par(ann=FALSE)
lines(histyes$mids,histyes$counts,col="red")
par(ann=TRUE)
#legend(10, 200, legend = c('correct','incorrect'), col = c("red","black"), lty="0")}
}
"foof.image" <-
function(xx,mycol=grey(seq(1,0,-0.1)),cut.u,cut.l,dff,vec.x,vec.y,txt=T,...){

# creates a foof image plot, with numbers superimposed (optinal)
#
# variables with (o) are optional
#
# xx matrix with numbers to be displayed in the image
# mycol (o) color scheme for the image - default is grey with 10 levels
# cut.u (o) upper threshold for values to be plotted in the image
# cut.l (o) lower threshold for values to be plotted in the image
# dff (o) value at which numbers appear in white in the image
# vec.x (o) labels for x-axis
# vec.y (o) labels for y-axis
# txt (o) logical - if true, numbers will be superimposed

	yy <- xx
	if(!missing(cut.u)) yy[yy>cut.u] <- cut.u
	if(!missing(cut.l)) yy[yy<cut.l] <- cut.l
	n1 <- dim(xx)[1]
	n2 <- dim(xx)[2]
		for(i in 1:n1){
			for(j in 1:n2){
				if(is.na(xx[i,j])) { xx[i,j] <- -1 }}}

	if(missing(vec.x)|missing(vec.y)){
		image(1:n1,1:n2,yy,col=mycol,...)}
	else{
		image(yy,xaxt="n",yaxt="n",col=mycol,...)
		axis(1,1:n1,vec.x)
		axis(2,1:n2,vec.y)}

	if(missing(dff)) dff <- min(xx)+0.4*diff(range(xx))

	if(txt){
		for(i in 1:n1){
			for(j in 1:n2){
				if(is.na(xx[i,j])) { xx[i,j] <- -1 }
				if(xx[i,j]<dff) text(i,j,xx[i,j])
					else text(i,j,xx[i,j],col="white")}}}

	invisible()}
"pf" <-
function(zscore,aco,targetLength,ratio) {
	value <-
		1.1715048*zscore +
		0.2423547*aco +
		0.0307338*targetLength -
		5.1286628*abs(log(ratio)) -
		0.0222145*zscore*aco -
		0.0043470*zscore*targetLength -
		8.5475612
	value
}
"n2f" <-
function (array)
{
	array2 <- array
	array2[ array2 == 0 ] <- 'no'
	array2[ array2 == 1 ] <- 'yes'
	array2 <- as.factor(array2)
	array2
}
"histnn" <-
function(x = stop("Needs x"),...) {
	if (length(x) > 0) {
		n <- as.numeric(x)
		hist(n,...)
	}
}
"doFlipFilter" <-
function (si=stop("need si"),resultid=stop("needs resultid"),filterid=stop("need filterid"))
{
	url <- paste("ddb?s=resultFilter&rcall=1&si=",si,"&resultid=",resultid,"&filterflipc",filterid,"=1",sep='')
	ret.value <- read.table(url,header=F)
	# write code to deal with ret.value
	# returned value is the operator value in DDB - 1: ==; 4: !=
	ret.value
	#url
}

"doGetResult" <-
function (si=stop("Needs si"),resultid=stop("needs resultid"))
{
	read.table(paste("ddb?si=",si,"&resultid=",resultid,"&s=resultExportRtab",sep='') ,header=T)
}

"doModel" <-
function (si=stop("need si"),cv=stop("need cv"),type="top")
{
	resultid <- 117
	filterid <- 141
	ret <- doSetFilterValue(si=si,resultid=resultid,filterid=141,filtervalue=cv)
	if (ret == 0) stop("Wrong")
	ret <- doFlipFilter(si=si,resultid=resultid,filterid=filterid)
	if (ret == 1) {
		ret <- doFlipFilter(si=si,resultid=resultid,filterid=filterid)
	}
	if (ret != 4) stop("Wrong")
	dfTrain <- doGetResult(si=si,resultid=resultid)
	ret <- doFlipFilter(si=si,resultid=resultid,filterid=filterid)
	if (ret != 1) stop("Wrong")
	dfEval <- doGetResult(si=si,resultid=resultid)
	attach(dfTrain)
#	model <- glm(correctSuperfamily~zscore+convergence+predictionContactOrder+ratio+aratio+bratio,family=binomial)
	model <- glm(correctSuperfamily~zscore+predictionContactOrder,family=binomial)
	dfTrain$response <- predict(model)
	dfTrain$newprob <- 1/(1+1/exp(dfTrain$response))
	modelNull <- glm(correctSuperfamily~zscore,family=binomial)
	dfTrain$responseNull <- predict(modelNull)
	dfTrain$newprobNull <- 1/(1+1/exp(dfTrain$responseNull))
	dfEval$response <- predict(model,newdata=dfEval)
	dfEval$newprob <- 1/(1+1/exp(dfEval$response))
	dfEval$responseNull <- predict(modelNull,newdata=dfEval)
	dfEval$newprobNull <- 1/(1+1/exp(dfEval$responseNull))
	par(mfrow=c(1,2))
	plotLineHist(dfEval$newprob,dfEval$correctSuperfamily)
	plotLineHist(dfEval$newprobNull,dfEval$correctSuperfamily)
	model
}

"doSetFilterValue" <-
function (si=stop("need si"),resultid=stop("need resultid"),filterid=stop("need filterid"),filtervalue=stop("need filtervalue"))
{
	url <- paste("ddb.cgi?s=resultFilter&rcall=1&si=",si,"&resultid=",resultid,"&changefiltervalue",filterid,"=",filtervalue,sep='')
	ret.value <- read.table(url,header=F)
	# write code to deal with ret.value
	ret.value
	#url
}

"plotLineHist" <-
function (var,def,breaks='scott',lwd=4,y2lab="ratio",...)
{
	hist <- hist(var,breaks=breaks,plot=FALSE,xlim=c(0,1)) # defined break points
	histno <- hist(var[def == 'no' | def == 0],breaks=hist$breaks,plot=FALSE) # incorrect
	histyes <- hist(var[def == 'yes' | def == 1],breaks=hist$breaks,plot=FALSE) # correct	
	max <- max(histyes$counts,histno$count)
	plot(histno$mids,histno$counts,type="l",lwd=lwd,ylim=c(0,max),...) # plot incorrect
	par(ann=FALSE) # dont put anything on the labels
	lines(histyes$mids,histyes$counts,col="red",lwd=lwd) # correct line
	par(ann=TRUE) # put things on labels again
	par(new=T,xaxs="r") # plot in existing graph
	# plot blue diff-line
	plot(histno$mids,(histyes$counts/(histno$counts+histyes$counts)),axes=F,ylab="",xlab="",type="l",col="blue",lwd=lwd,ylim=c(0,1))
	# put on right axis
	axis(side=4) # write to right
	mtext(side=4,line=1.8,y2lab) # write to right
	abline(0,1,lwd=lwd/2)
}
# below from ROSETTA/bench.R
"as.data.frame.rosettaBenchmark" <-
function(x, ... ) {
	class(x) <- "data.frame"
	x
}
"as.data.frame.rosettaBenchmarkEnrichment" <-
function(x, ... ) {
	class(x) <- "data.frame"
	x
}
"as.data.frame.rosettaBenchmarkPercentile" <-
function(x, ... ) {
	class(x) <- "data.frame"
	x
}
"connectDb" <-
function( host = Sys.getenv('BENCH_DBHOST'), default.rec = 5000000, dbname = 'bench', user = "bench", password = Sys.getenv('BENCH_PASS') )
{
	library(RMySQL)
	con<-MySQL(fetch.default.rec = default.rec )
	#print(paste("USER: ",user))
	#print(paste("PW: ",password))
	#print(paste("HOST: ",host))
	#print(paste("DBname: ",dbname))
	dbh <- dbConnect( con, user = user, password = password, host = host, dbname = dbname )
	#dbSendQuery(dbh,"USE bench")
	dbh
}
"enrichment" <-
function(x, ...)
{
	if(is.null(class(x))) class(x) <- data.class(x)
	UseMethod("enrichment", x)
	#UseMethod("enrichment", x, ...)
}
"enrichment.default" <-
function (x = stop( "No data given" ), percentile = 0.15, enrColumn = "score", column = "rms")
{
	index <- round(nrow( x )*percentile)
	columnCutoff <- x[sort(x[,enrColumn], index=TRUE)$ix[ index ], enrColumn]
	returnCutoff <- x[sort(x[,column], index=TRUE)$ix[ index ], column]
	expected <- length(x[ x[,enrColumn] <= columnCutoff,1])
	actual <- length(x[ x[,enrColumn] <= columnCutoff & x[,column] <= returnCutoff ,1])
	p <- (actual/expected)/percentile
	#c(nrS,expected,actual,p,percentile,column,returnCutoff,enrColumn,columnCutoff)
	structure(list( length = nrow(x),expected = expected, actual = actual, p = p,percentile = percentile,column = column, returnCutoff = returnCutoff,enrColumn = enrColumn, columnCutoff = columnCutoff))
}
"enrichment.rosettaBenchmark" <-
function(x, ... )
{
	class(x) <- "data.frame"
	level <- unique(x$targetkey)
	n=0
	for (i in level) {
		n=n+1
		df <- x[ x$targetkey == i, ]
		enr <- enrichment(df,...)
		enr$targetkey <- i
		if (n == 1) {
			res <- data.frame(enr)
		} else {
			res[n,] <- data.frame(enr)
		}
	}
	class(res) <- "rosettaBenchmarkEnrichment"
	res
}
"percentile" <-
function(x, ...)
{
	if(is.null(class(x))) class(x) <- data.class(x)
	UseMethod("percentile", x)
	#UseMethod("percentile", x, ...)
}
"percentile.default" <-
function (x = stop( "No data given" ), percentile = 0.15, column = "rms")
{
	index <- round(nrow( x )*percentile)
	if (percentile == 0) index = 1
	value <- x[sort(x[,column], index=TRUE)$ix[ index ], column]
	structure(list( length = nrow(x),percentile = percentile,column = column, value = value))
}
"percentile.rosettaBenchmark" <-
function(x, ... )
{
	class(x) <- "data.frame"
	level <- unique(x$targetkey)
	n=0
	for (i in level) {
		#df <- x[ x$targetkey == i, ]
		n=n+1
		#per <- percentile(x[ x$targetkey == i, ])
		per <- percentile(x[ x$targetkey == i, ],...)
		#per <- percentile(df,...)
		per$targetkey <- i
		if (n == 1) {
			res <- data.frame(per)
		} else {
			res[n,] <- data.frame(per)
		}
	}
	class(res)<-"rosettaBenchmarkPercentile"
	res
}
# above from ROSETTA/bench.R
