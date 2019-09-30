![compile status](https://gitlab.com/ukos-git/igor-swnt-massanalysis/badges/master/pipeline.svg)

# igor-swnt-massanalysis
A tool for performing various actions on top of a collection of spectra

# WIP
under developement. No clean commit / feature-branch system right now.

# measurement setup
The camera images and spectra from this program are loaded with [PLEMd2](https://github.com/ukos-git/igor-swnt-plem) and recorded with a versatile labview program called [PLEMv3](https://github.com/ukos-git/labview-plem)

# images
The sample used in this experiment consists of 2µm broad trench structure with Carbon Nanotubes freely suspended in air over the tranches. Images are used to obtain carbon nanotube positions. Carbon Nanotubes from those positions are used for spectra acquisition.
![Typical image of Andor Clara](https://github.com/ukos-git/igor-swnt-massanalysis/blob/master/images/example.png)

Background is fit with a large gaussian to the sum of all images that were loaded to substract the illumination of the lamp:
![Background substraction for Andor Clara](https://github.com/ukos-git/igor-swnt-massanalysis/blob/master/images/getCoordinates_FitBackground_contour.png)

24 Images are combined to a single image that gives a good overview where to find the carbon nanotubes:
![24 images combined at best focus](https://github.com/ukos-git/igor-swnt-massanalysis/blob/master/images/combined-images/SMAgetCoordinatesfullImageSi.png)

The same can be done for different cameras. Here we use a InGaAs Camera that records a lot more carbon nanotubes but due to its larger pixel size not as accurate as the silicon camera above:
![Xenics Xeva](https://github.com/ukos-git/igor-swnt-massanalysis/blob/master/images/combined-images/SMAgetCoordinatesfullImageInGaAs.png)

From those images, good carbon nanotube positions are picked and a coordinate list is generated. From each position spectra are recorded:
![typical trench scan](https://github.com/ukos-git/igor-swnt-massanalysis/blob/master/images/combined-images/SMAgetCoordinatesfullImageSi_zoom.png)
