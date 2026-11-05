dir0 = getDirectory("Working folder");
dir1 = dir0 + "a-file\\";
dir2 = dir0 + "b-file_s\\";
dir3 = dir0 + "c-roi_s\\";
dir4 = dir0 + "d-roi\\" ;
dir5 = dir0 + "e-nuclei\\" ;

norm = dir0 + "z1-normalized\\"
no_bg = dir0 + "z2-no_background\\"
no_bg_hor = dir0 + "z3-no_background_horizontal\\"
parameters = dir0 + "z4-nuclei_parameters\\"

// ---------- configuration ----------
ball_size = 50;                 // rolling-ball radius (pixels) for background subtraction
                                // originally hard-coded as rolling=30
resizing_factor = "0.2";
ROIs_to_segment_orig = 500;
// ---------------- create folders if missing ----------------
// File.makeDirectory only creates the folder (and parents) if it
// does not already exist -> safe to call on every run.
folders = newArray(
    dir1,
    dir2,
    dir3,
    dir4,
    dir5,
    norm, no_bg, no_bg_hor, parameters
);

for (i = 0; i < folders.length; i++) {
    if (!File.exists(folders[i])) {
        File.makeDirectory(folders[i]);
        print("Created: " + folders[i]);
    } else {
        print("Exists : " + folders[i]);
    }
}

print("All folders are ready.");
//setBatchMode("hide");
function contains( array, value ) {
    for (i=0; i<array.length; i++) 
        if ( array[i] == value ) return true;
    return false;
}




list = getFileList(dir1);
// Resizing to 0.2 the size of the original image
print("\n Welcome to NuS, the Fiji macro for Nuclear Segmentation! made by WuTimS9 on GitHub");
print("Starting resizing by a factor of " + resizing_factor);
start = getTime();
counter = 0;
for (i = 0; i<list.length; i++){
        file_original = list[i];
        file_small = replace(file_original, ".tif", "_s.tif");
        list_small = getFileList(dir2);
    	if (contains(list_small, file_small)) 
    	{
    		print(file_original + " was already resized.");
    		continue;
    	} 
        open(dir1 + list[i]);
		run("Scale...", "x=" +resizing_factor+ " y=" + resizing_factor +" interpolation=Bilinear average create");
		run("8-bit");
        saveAs("Tiff", dir2 + file_small); 
		run("Close All");
		counter = counter + 1;
        }
end = getTime();
if (counter != 0){
print("Resized " + counter + " images in " + (end - start)/1000 + " seconds");
}
 
 // Stardist mask creation
start = getTime();
counter = 0;

run("ROI Manager...");
small_list = getFileList(dir2); 
print("\nStarting StarDist nuclei ROI creation!");
for (i=0; i<small_list.length; i++) {
	
	file_small = small_list[i];
	roi_small = replace(file_small, "_s.tif", "_roi_s.zip");
	roi_small_list = getFileList(dir3);
	if (contains(roi_small_list, roi_small)) {
	print(file_small + " has ROIs ready.");
	continue;
	}
	open(dir2+file_small);
	selectWindow(file_small);
	// run stardist
	run("Command From Macro", "command=[de.csbdresden.stardist.StarDist2D], args=['input':'" + 
	file_small + "', 'modelChoice':'Versatile (fluorescent nuclei)', " + 
	"'normalizeInput':'true', 'percentileBottom':'1.0', 'percentileTop':'99.8', 'probThresh':'0.5',"+
	" 'nmsThresh':'0.4', 'outputType':'Both', 'nTiles':'1', 'excludeBoundary':'2', 'roiPosition':'Automatic', 'verbose':'false',"+
	" 'showCsbdeepProgress':'false', 'showProbAndDist':'false'], process=[false]");
	selectWindow("Label Image");
	roiManager("save", dir3 + roi_small);
	roiManager("Deselect");
	roiManager("Delete");
	run("Close All");
	counter = counter + 1;
}

end = getTime();
if (counter != 0){
print("Created " + counter + " ROIs in " + (end - start) / 1000 + " seconds");}


// Resizing ROIs
print("\nResizing ROIs for nuclear segmentation.");
counter = 0;
start = getTime();
list_roi_small = getFileList(dir3);

for (i = 0; i < list_roi_small.length; i++) {
	roi_small = list_roi_small[i];
	roi_title = replace(roi_small, "_roi_s.zip", "_roi.zip");
	file_original = replace(roi_small, "_roi_s.zip", ".tif");
	file_small = replace(roi_small, "_roi_s.zip", "_s.tif");
	
	roi_title_list = getFileList(dir4);
	if (contains(roi_title_list, roi_title)) {
	print(roi_small + " was already resized.");
	continue;
	}
	
	open(dir2+ file_small);
	height2 = getHeight();
	title = getTitle();
	open(dir1+ file_original);
	height1 = getHeight();
	// We obtain the scaling factor
	scale = height1/height2;
	run("ROI Manager...");
	
	roiManager("Open", dir3 + roi_small) ;
	selectImage(file_original);
	for (m = 0; m < roiManager("count"); m++){	
		roiManager("Select", m);
		RoiManager.scale(scale, scale, false);
	}
	roiManager("save", dir4 + roi_title);
	roiManager("deselect");
	roiManager("delete");
	run("Close All");
	counter++;
}
end = getTime();

if (counter != 0){
print("Resized" + counter + "ROI files in " + (end - start) / 1000 + " seconds\n");}

// Segmentation

run("Set Measurements...", "area mean standard modal min center fit shape median display redirect=None decimal=2");
print("\nSegmenting nuclei from original images.");
counter = 0;
counter_images = 0;
start = getTime();
run("ROI Manager...");
list = getFileList(dir1);
ROI_list = getFileList(dir4);
nuclei_list = getFileList(dir5);
for (i = 0; i<ROI_list.length; i++)
    {
    ROIs_to_segment = ROIs_to_segment_orig;
    ROI_name = ROI_list[i];
    file_original = replace(ROI_name, "_roi.zip", ".tif");
    sheet_name = replace(ROI_name, "_roi.zip", "");
    
	if (contains(list, file_original) == false)
	{ 	print("Error: There is no " + file_original + " to be segmented.");
		continue
		}
    roiManager("Open", dir4 + ROI_name);
    open(dir1 + file_original);
    Image.removeScale;
    selectImage(file_original);
    getDimensions(width, height, channels, slices, frames);
   
    if (ROIs_to_segment > roiManager("count")){
    	ROIs_to_segment = roiManager("count");
    }
    total_ROI = roiManager("count");
	segmented_ROIs = 0;
	ready_nuclei = 0;
	
    for (m = 0; m < ROIs_to_segment; m++)  // roiManager("count")
        {
        if (m == total_ROI){break}
        selectImage(file_original);
        roiManager("Select", m);
        roiManager("Update");
        // Skips nuclei at the border
        getSelectionBounds(x, y, width1, height1);        
        ROIs_to_segment++;
        if ((x<=0)||(y<=0)||((x+width1+10)>=width)||((y+height1+10)>=height)) {} 
        else {
			RoiID = Roi.getName;
			nucleus_name =  RoiID + "_" + sheet_name+ ".tif" ;
			
			//Checks if nucleus was already segmented
			if (contains(nuclei_list, nucleus_name)){ 
				ready_nuclei++;
				continue
				}
			
			// Measuring
			run("Measure");
			selectWindow("Results");
			updateResults();
			
			// Segmentation itself	
			ROIs_to_segment = ROIs_to_segment - 1;
        	segmented_ROIs++;
	        run("Duplicate...", " ");
	        run("Clear Outside");	
			saveAs("Tiff", dir5 + nucleus_name); 
	        close(nucleus_name);
      		}
        }
        roiManager("deselect");
        roiManager("delete");
        // saving results
        print( "Segmented "+segmented_ROIs+" new nuclei, "+
        "total nuclei from "+ file_original+ " is "+ (ready_nuclei+segmented_ROIs)+
        "\n Total nuclei analyzed = " +ROIs_to_segment);
        counter = counter + segmented_ROIs; 
        counter_images++;
        // saving table
        if (counter > 0){
		getDateAndTime(year, month, dayOfWeek, dayOfMonth, hour, minute, second, msec);
        result_name =  sheet_name + "" + year + "_" + month + "_" + dayOfMonth + "_" + hour + "_" + minute + ".csv";
		saveAs("Results", parameters + result_name);
		selectWindow("Results");
		Table.deleteRows(0, ROIs_to_segment);
				}
        run("Close All");
	    }
	    end = getTime();
print(counter+ " nuclei segmented from " +counter_images+ " images in " + (end - start) / 60000 + " minutes\n");



norm  = dir0 + "z1-normalized\\";
no_bg  = dir0 + "z2-no_background\\";
no_bg_hor = dir0 + "z3-no_background_horizontal\\";
// ---------------- create folders if missing ----------------
// File.makeDirectory only creates the folder (and parents) if it
// does not already exist -> safe to call on every run.
folders = newArray( norm, no_bg, no_bg_hor
);

for (i = 0; i < folders.length; i++) {
    if (!File.exists(folders[i])) {
        File.makeDirectory(folders[i]);
        print("Created: " + folders[i]);
    } else {
        print("Exists : " + folders[i]);
    }
}
print("All folders are ready.");
if (!File.exists(norm))  File.makeDirectory(norm);
if (!File.exists(no_bg))  File.makeDirectory(no_bg);
if (!File.exists(no_bg_hor)) File.makeDirectory(no_bg_hor);

// ---------- helper ----------
function contains(array, value) {
    for (var k = 0; k < array.length; k++)
        if (array[k] == value) return true;
    return false;
}

// ============================================================
// Stage 1 : 8-bit + normalization  ->  norm
// ============================================================
print("\n--- Stage 1 : 8-bit normalization ---");
list         = getFileList(dir5);
existing_eq  = getFileList(norm);
setBatchMode("hide");
saved = 0; skipped = 0;
for (i = 0; i < list.length; i++) {
    title = list[i];
    if (contains(existing_eq, title)) {
        print(title + " already in f-nuclei-8bit, skipping.");
        skipped++;
        continue;
    }
    open(dir5 + list[i]);
    title = getTitle();
    run("Enhance Contrast...", "saturated=0.0 normalize");
    run("8-bit");
    saveAs("Tiff", norm + title);
    run("Close All");
    saved++;
}
print("8-bit normalization: " + saved + " saved, " + skipped + " skipped.");
eq_saved = saved; eq_skipped = skipped;

// ============================================================
// Stage 2 : background removal  ->  no_bg
// ============================================================
print("\n--- Stage 2 : background removal (ball_size = " + ball_size + ") ---");
setBatchMode(true);
list         = getFileList(dir5);
existing_bg  = getFileList(no_bg);
saved = 0; skipped = 0;
for (i = 0; i < list.length; i++) {
    if (contains(existing_bg, list[i])) {
        print(list[i] + " already in #4b-no-background, skipping.");
        skipped++;
        continue;
    }
    open(dir5 + list[i]);
    image_name = getTitle();
    setMinAndMax(0, 65535);
    print(image_name);
    selectImage(image_name);

    run("Select None");
    run("Duplicate...", "title=bg");
    setMinAndMax(0, 65535);
    run("8-bit");

    setAutoThreshold("Moments dark no-reset");
    run("Create Selection");

    run("Set Measurements...", "area mean standard modal min center perimeter bounding fit shape median redirect=None decimal=2");
    run("Measure");
    median = (getValue("Median"));
    run("Make Inverse");

    run("Min...", "value=" + median);
    run("Select None");
    run("Subtract Background...", "rolling=" + ball_size + " create sliding");   // <-- ball_size used here
    run("16-bit");
    setMinAndMax(0, 65535);
    run("Multiply...", "value=256");

    imageCalculator("Subtract create", image_name, "bg");
    selectImage(image_name);
    close();
    selectImage("Result of " + image_name);
    rename(image_name);

    run("Enhance Contrast", "saturated=0.35 normalize");
    run("Apply LUT");
    run("Gaussian Blur...", "sigma=1");
	
    run("Apply LUT");
    run("8-bit");
    saveAs("Tiff", no_bg + image_name);
    run("Close All");
    saved++;
}
print("Background removal: " + saved + " saved, " + skipped + " skipped.");
bg_saved = saved; bg_skipped = skipped;

// ============================================================
// Stage 3 : horizontal rotation  ->  no_bg_hor
// ============================================================
print("\n--- Stage 3 : horizontal rotation ---");
setBatchMode(true);
run("Set Measurements...", "area mean standard modal min center perimeter bounding fit shape median redirect=None decimal=2");

list_bg      = getFileList(no_bg);
existing_hor = getFileList(no_bg_hor);
saved = 0; skipped = 0;
for (i = 0; i < list_bg.length; i++) {
    if (contains(existing_hor, list_bg[i])) {
        print(list_bg[i] + " already in #5a-horizontal, skipping.");
        skipped++;
        continue;
    }
    open(no_bg + list_bg[i]);
    image_name = getTitle();
    selectImage(image_name);

    run("Select None");
    setAutoThreshold("MinError dark no-reset");
    run("Create Selection");
    run("Convex Hull");
    run("Measure");
    angle  = getValue("Angle");
    angle1 = parseInt(angle);
    run("Select None");
    run("Rotate... ", "angle=" + angle1 + " grid=1 interpolation=Bilinear enlarge");

    resetThreshold;
    setAutoThreshold("MinError dark no-reset");
    run("Create Selection");
    run("To Bounding Box");
    run("Crop");
    run("8-bit");
    saveAs("Tiff", no_bg_hor + image_name);
    run("Close All");
    saved++;
}
print("Horizontal rotation: " + saved + " saved, " + skipped + " skipped.");
hor_saved = saved; hor_skipped = skipped;

// ============================================================
// Summary
// ============================================================
setBatchMode(false);
print("\n==================== SUMMARY ====================");
print("  ball_size (background) : " + ball_size);
print("  8-bit normalization    : " + eq_saved  + " saved, " + eq_skipped  + " skipped");
print("  Background removal     : " + bg_saved  + " saved, " + bg_skipped  + " skipped");
print("  Horizontal rotation    : " + hor_saved + " saved, " + hor_skipped + " skipped");
print("=================================================");