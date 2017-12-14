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
