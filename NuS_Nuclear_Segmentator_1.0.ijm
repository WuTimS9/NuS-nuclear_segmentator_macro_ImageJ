
dir0 = getDirectory("Working folder");
print(dir0)
dir1 = dir0 + "#3a-file\\"; // bakcslashes shoud be doubles to be registered as one
dir2 = dir0 + "#3b-file_s\\";
dir3 = dir0 + "#3c-roi_s\\";
dir4 = dir0 + "#3d-roi\\" ;
dir5 = dir0 + "#3e-nuclei\\" ;
dir6 = dir0 + "#3f-nuclei\\" ;
dir7 = dir0 + "#3g-no-focus\\" ;
print(dir1, dir2, dir3, dir4); 

list = getFileList(dir1);

//// First the resizing

for (i = 0; i<list.length; i++)
    {
        open(dir1 + list[i]);
        // file names
        
        title1 = getTitle();
        title2 = replace(title1, ".tif", "_s.tif");
        title3 = replace(title1, ".tif", "_roi_s.zip");
        title4 = replace(title1, ".tif", "_roi.zip");
        title5 = replace(title1, ".tif", "");
        title6 = replace(title1, ".tif", "1.tif");
        //
		run("Scale...", "x=0.2 y=0.2 interpolation=Bilinear average create");
		run("8-bit");
        saveAs("Tiff", dir2 + title2); 
		run("Close All");
        }
 
 ////// Then the ROI formation
 
 
run("ROI Manager...");
list = getFileList(dir2); 
 
 // MAIN LOOP
for (i=0; i<list.length; i++) {
	open(dir2+list[i]);
 	
	// do some stuff to the images (i.e split, blur etc)
	
	title = getTitle; // registers the names of all open images
	//run("Split Channels");
	nuclei_image = title;
	selectWindow(nuclei_image);
	//run("Gaussian Blur...", "sigma=2");
	 
	// run stardist
	run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], args=['input':'" + nuclei_image + "', 'modelChoice':'Versatile (fluorescent nuclei)', 'normalizeInput':'true', 'percentileBottom':'1.0', 'percentileTop':'99.8', 'probThresh':'0.5', 'nmsThresh':'0.4', 'outputType':'Both', 'nTiles':'1', 'excludeBoundary':'2', 'roiPosition':'Automatic', 'verbose':'false', 'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]");
	selectWindow("Label Image");
	
	title_roi = replace(nuclei_image, "_s.tif", ""); // trunkates title
	roiManager("save", dir3 + title_roi + "_roi_s.zip");
	roiManager("Deselect");
	roiManager("Delete");
	run("Close All");
}
//////////// RESIZING THE ROIS
list = getFileList(dir2);
for (i = 0; i < list.length; i++) {
	
	open(dir2+ list[i]);
	height2 = getHeight();
	title = getTitle(); // here we have the name of the file ex: "a_s_roi.zip"
	// the file is open _roi_s, now we need to open the corresponding file_s and _s in the dir1 and dir2
	title1 = replace(title, "_s.tif", ".tif");
	open(dir1+title1);
	height1 = getHeight();
	
	// We obtain the scaling factor
	scale = height1/height2;
	//print(scale);
	run("ROI Manager...");
	
	
	title3 = replace(title1, ".tif", "_roi_s.zip"); 
	roiManager("Open", dir3 + title3) ;
	selectImage(title1);
	for (m = 0; m < roiManager("count"); m++){	
		roiManager("Select", m);
		RoiManager.scale(scale, scale, false);
	}
	title4 = replace(title3, "_roi_s.zip", "_roi.zip");
	roiManager("save", dir4 + title4);
	roiManager("deselect");
	roiManager("delete");
	run("Close All");
		//run("Clear Outside");
		//saveAs("Tiff", dir2 + title + i + "_Label.tif"); 

	
}


//////////// NOW SEGMENTING


list = getFileList(dir1);

for (i = 0; i<list.length; i++)
    {
        open(dir1 + list[i]);
        // file names
        
        title1 = getTitle();
        title2 = replace(title1, ".tif", "_s.tif");
        title3 = replace(title1, ".tif", "_roi_s.zip");
        title4 = replace(title1, ".tif", "_roi.zip");
        title5 = replace(title1, ".tif", "");
        title6 = replace(title1, ".tif", "1.tif");
        //
    roiManager("Open", dir4 + title4) ;
    selectImage(title1);
    getDimensions(width, height, channels, slices, frames);
    for (m = 0; m < roiManager("count"); m++)
        {
        selectImage(title1);
        roiManager("Select", m);
        // where to select whether the image is at the edge or not
        getSelectionBounds(x, y, width1, height1);
        if ((x<=0)||(y<=0)||((x+width1+10)>=width)||((y+height1+10)>=height)) {} //roiManager("delete");
        // here we have <= because sometimes the mask is outside the image area, and also the +10,
        // it can be regulated for example the x+witdth1+10 the 10 can be changed to another number)
        else {
        run("Duplicate...", " ");
        
        run("Clear Outside");
        saveAs("Tiff", dir5 + title5 + m + ".tif"); 
        close(title5 + m + ".tif");}
        }
        roiManager("deselect");
        roiManager("delete");
        run("Close All");

        
    }
 /////   FOCUS SORTING 
    //open a dialogue to select directory of images to open and assign it to a variable (eg input) 
input = dir5
//open a dialogue to select location where images/results are to be stored 
output = dir6 
out_of_focus = dir7
list = getFileList(input); 

setBatchMode(true);

 	for (i = 0; i<list.length; i++) {
 	   	open(input+list[i]);


 	//insert macro here   	
 	original = getImageID();
 	filename = getInfo("image.filename");
 	run("Duplicate...", " ");
 	
run("Measure");
mean = getResult("Mean"); 
run("Make Inverse");
print("value=" + mean);
run("Add...", "value="+mean);
run("Subtract Background...", "rolling=5");
run("Enhance Contrast...", "saturated=0.35");
run("Measure");
getStatistics(area, mean, min, max, std, histogram);
/// STD IS THE ONE THAT CHARACTERIZED THE FOCUS 
	if (std > 1) {
		selectImage(original);
		saveAs("Tiff",output+filename);
		run("Close All");
	}
else {
		selectImage(original);
		saveAs("Tiff",out_of_focus+filename);
		run("Close All");}
	}
   

