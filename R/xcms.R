library(xcms)

## list all mzXML files (profile and/or centroid mode) In a directory
mzxml.files <- function(dir, profile=TRUE, centroid=TRUE) {
	pattern <- NULL
	if (profile && centroid)
		pattern <- "\\.mzXML$"
	else if (profile)
		pattern <- "[^(_c)]\\.mzXML$"
	else if (centroid)
		pattern <- "_c\\.mzXML$"
	list.files(dir, pattern=pattern, full.names=TRUE)
}
## plot image of MS data from mzXML file
## optional parameters: "massrange", "timerange" to plot only part of the data
plot.image <- function(filename, mz.step=0.1, ...) {
	xraw <- xcmsRaw(filename, profstep=mz.step)
	image(xraw, ...)
}
## generate PNG image of MS data
## optional parameters: "width", "height" of PNG In pixels
plot.png <- function(ms.file, png.file, ...) {
	png(png.file, ...)
	plot.image(ms.file)
	dev.off()
}
## generate PNG images for all mzXML files In a directory
plot.dir <- function(ms.dir, png.dir, profile=TRUE, centroid=TRUE, ...) {
	files <- mzxml.files(ms.dir, profile, centroid)
	for (file in files) {
		png.file <- sub("mzXML$", "png", basename(file))
		plot.png(file, file.path(png.dir, png.file), ...)
	}
}
