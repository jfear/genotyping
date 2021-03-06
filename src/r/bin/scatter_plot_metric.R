#!/usr/bin/env Rscript

# Author:  Iain Bancarz, ib5@sanger.ac.uk
# October 2012

args <- commandArgs(TRUE)
data <- read.table(args[1]) # metric values
pb <- read.table(args[2], header=TRUE) # plate boundaries
pn <- read.table(args[3]) # plate names
metricName <- args[4]
metricMean <- as.numeric(args[5])
metricSd <- as.numeric(args[6])
metricThresh1 <- as.numeric(args[7]) 
metricThresh2 <- as.numeric(args[8]) ## for gender; NA otherwise
sdThresh <- as.logical(args[9]) # boolean; is threshold in standard deviations?
plotNum <- args[10]
plotTotal <- args[11]
outPath <- args[12]
# metricMean, metricSd refer to whole dataset, not just current plates
# can be NA if sdThresh is FALSE

index <- data$V1
metric <- data$V2
pass <- data$V3

sdLimit <- 10
if (metricName=='heterozygosity') { 
  ymin <- 0
  ymax <- 1.15 # allow space for legend
} else if (metricName=='gender') {
  ymin <- 0
  ymax <- 0.54
} else if (metricName=='xydiff') {
  ymin <- metricMean - sdLimit*metricSd
  ymax <- metricMean + sdLimit*metricSd
} else if (metricName=='identity' || metricName=='duplicate') {
  ymin <- 0
  ymax <- 1.2
} else if (metricName=='magnitude') {
  ymin <- 0.8
  ymax <- 1.25
} else { # call_rate
  ymin <- 0.8
  ymax <- 1.04
}
metric[metric<ymin] <- ymin
metric[metric>ymax] <- ymax
xmin <- 0
if (sdThresh) {
  xmax = 1.2*max(index)
} else {
  xmax = 1.15*max(index)
}

process.pn <- function(pn) {
  # remove plate names if they are too close together
  # plate must be at least 4% of total width to include name
  names <- pn$V1
  positions <- pn$V2
  total <- length(positions)
  minDist <- total*0.04
  if (total>=2) {
    for (i in 1:(total-1)) {
      if ((positions[i+1] - positions[i])  < minDist) {
        names[i] <- ""
      }
    }
  }
  newPlateNames <- data.frame("V1"=names, "V2"=positions)
  return(newPlateNames)
}

sd.lines <- function(metricMean, metricSd, metricThresh) {
  # draw horizontal lines to show standard deviations
  metricMax <- metricMean+metricThresh*metricSd
  metricMin <- metricMean-metricThresh*metricSd
  abline(h=metricMean, lty=2)
  minTextHeight <- 0.04
  if (metricSd > minTextHeight) {
    for (i in 1:(floor(metricThresh) - 1)) {
      high = metricMean+i*metricSd
      low = metricMean-i*metricSd
      abline(h=high, col="black", lty=3)
      abline(h=low, col="black", lty=3)
      text(max(index), high, paste("Mean +", i, "SD\n"), pos=4, cex=0.6)
      text(max(index), low, paste("Mean -", i, "SD\n"), pos=4, cex=0.6)
    }
  }
  abline(h=metricMax, col="red", lty=2)
  abline(h=metricMin, col="red", lty=2)
  mt <- metricThresh
  if (metricSd*mt > minTextHeight) {
    text(max(index), metricMax, paste("Mean +", mt, "SD\n"), pos=4, cex=0.6)
    text(max(index), metricMin, paste("Mean -", mt, "SD\n"), pos=4, cex=0.6)
    text(max(index), metricMean, "Mean\n", pos=4, cex=0.6)
  }
}

write.legends <- function(name, mean, sd) {
  # write legends to plot for given metric name, mean and sd
  legend("topright",
         c(paste("Pass/fail threshold for", name),
           "Passed all metrics",
           paste("Failed", name, "only"),
           paste("Failed", name, "and at least one other metric"),
           paste("Passed ",name,", failed at least one other metric", sep="")),
         bg="white",
         pch=c(NA,16,3,5,4),
         col=c("red","black","red","purple","blue"),
         lty=c(2,NA,NA,NA,NA),cex=0.7)
  legend("topleft",
         c(paste("Mean =", signif(mean,4)),
           paste("SD =", signif(sd,4))),
         bg="white", cex=0.7)
}

ylab.name <- function(metricName) {
  if (metricName=='gender') {
    ylab.name <- "chr_X heterozygosity"
  } else if (metricName=='duplicate') {
    ylab.name <- "maximum similarity on test panel"
  } else if (metricName=='identity') {
    ylab.name <- "probability of identity with QC plex results"
  } else if (metricName=='magnitude') {
    ylab.name <- "normalised magnitude of intensity"
  } else {
    ylab.name <- metricName
  }
  return(ylab.name)
}

plot.pdf <- function(index, metric, pass, pn, pb, metricName, metricMean,
                     metricSd, metricThresh1, metricThresh2, sdThresh,
                     plotNum, plotTotal, xmin, xmax, ymin, ymax, outPath) {
  pdf(outPath, width=11.5, height=8.1, paper="a4r") # landscape format
  bottomMargin = 9
  par('mar'=c(bottomMargin,6,4,2)+0.1)
  myTitle = paste(metricName,"by sample and plate\nPlot",plotNum,"of",
    plotTotal,"for",metricName)
  myYlab = ylab.name(metricName)
  # start with blank plotting area
  plot(index, metric, type="n",  xlim=c(0,xmax), ylim=c(ymin,ymax),
       xaxt="n", xlab="", ylab=myYlab, main=myTitle)
  axis(1, pn$V2, pn$V1, las=3, cex.axis=0.7) # plate names
  mtext("Plate", side=1, line=bottomMargin - 2)
  shade <- rgb(190, 190, 190, alpha=80, maxColorValue=255)
  shadeTotal = length(pb$Start)
  if (shadeTotal != 0) {
    for (i in 1:shadeTotal) { # shade even-numbered plate areas
      rect(pb$Start[i], ymin, pb$End[i], ymax, density=100, col=shade)
    }
  }
  # plot points on top of shading
  points(index[pass==0], metric[pass==0], cex=0.5, col="black", pch=16)
  points(index[pass==1], metric[pass==1], cex=0.6, col="red", pch=3)
  points(index[pass==2], metric[pass==2], cex=0.6, col="purple", pch=5)
  points(index[pass==3], metric[pass==3], cex=0.6, col="blue", pch=4)
  # pass/fail lines and legends
  if (sdThresh) {
    sd.lines(metricMean, metricSd, metricThresh1)
  } else if (metricName=='gender') {
    abline(h=metricThresh1, col="red", lty=2)
    abline(h=metricThresh2, col="red", lty=2)
    text(max(index), metricThresh1, "\n\nM_max", pos=4, cex=0.6)
    text(max(index), metricThresh2, "F_min\n", pos=4, cex=0.6)
  } else {
    abline(h=metricThresh1, col="red", lty=2)
    if (metricName=='call_rate' || metricName=='magnitude' ||
        metricName=='identity') {
      label="minimum\n"
    } else if (metricName=='duplicate') {
      label="maximum\n"
    }
    text(max(index), metricThresh1, label, pos=4, cex=0.6)
  }
  write.legends(metricName, metricMean, metricSd)
  dev.off()
}

pn <- process.pn(pn)

plot.pdf(index, metric, pass, pn, pb, metricName, metricMean,
         metricSd, metricThresh1, metricThresh2, sdThresh,
         plotNum, plotTotal, xmin, xmax, ymin, ymax, outPath)


# Author: Iain Bancarz <ib5@sanger.ac.uk>

# Copyright (c) 2012, 2016, 2017 Genome Research Limited. All Rights Reserved.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by the
# Free Software Foundation, either version 3 of the License, or (at your
# option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
