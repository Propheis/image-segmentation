// Base code for image segmentation
//
// Handles only greyscale images.


// Globals

PImage image[] = new PImage[2];

final int INPUT  = 0;
final int OUTPUT = 1;

int currentImage = INPUT;

PFont font;                // for drawing text

final int HISTO  = 0;
final int KMEANS = 1;
final int OTSU   = 2;

int methodApplied = -1;

// "constants"

final int winWidth  = 800;      // window width
final int winHeight = 800;      // window height
final int numPixelValues = 256; // pixels are in [0,255]

String imageFilename = "gourds.png"; // current image file


// Init

void settings() {

    // Set up screen
    
    size( winWidth, winHeight, P2D );
    smooth( 2 );
}


void setup()

{
    // Set up text font

    font = createFont( "Arial", 16, true );
    textFont( font );

    // load default image upon startup

    readImage( imageFilename );
}


// Draw to window

void draw() {

    background( color(255,255,255) );

    // Show the image, centred in the window

    image( image[currentImage], (winWidth-image[currentImage].width)/2, (winHeight-image[currentImage].height)/2 );

    // Show the subdivisions

    int w = image[INPUT].width;
    int h = image[INPUT].height;
    
    int xOffset = (winWidth - w)/2;
    int yOffset = (winHeight - h)/2;

    stroke(255);

    for (int i=1; i<numCols; i++) { // vertical subdivisions
       int x = (int) (i * w/(float)numCols);
       line( x+xOffset, 0+yOffset, x+xOffset, h-1+yOffset );
   }

    for (int i=1; i<numRows; i++) { // horizontal subdivisions
       int y = (int) (i * h/(float)numRows);
       line( 0+xOffset, y+yOffset, w-1+xOffset, y+yOffset );
   }

    // Status message: image filename, method, and thresholds

    String msg = imageFilename;

    if (currentImage == OUTPUT)
        switch (methodApplied) {
            case HISTO:
            msg = msg + " with " + str(numRows) + "x" + str(numCols) + " histogram thresholding (threshold = " + str(thresholds[0]) + ")";
            break;
            case KMEANS:
            msg = msg + " with k-means thresholding (k = " + str(numThresholds+1) + ", thresholds =";
            for (int i=0; i<numThresholds; i++)
                msg = msg + ' ' + str(thresholds[i]);
            msg = msg + ")";
            break;
            case OTSU:
            msg = msg + " with " + str(numRows) + "x" + str(numCols) + " Otsu's method (threshold = " + str(thresholds[0]) + ")";
            break;
        }

        fill( 255 );
        noStroke();
        rect( 10-4, winHeight-10-16-1, 16*msg.length()+4+4, 16+6 );

        fill( 0 );
        stroke( 255 );
        text( msg, 10, winHeight-10 );
    }


// Handle a key press

int numRows = 1;		// subdivision rows for Otsu
int numCols = 1;		// subdivision columns for Otsu

void keyPressed() {
    switch (key) {

        case CODED:
        switch (keyCode) {
            case RIGHT:
            numCols++;
            break;
            case LEFT:
            if (numCols > 1)
              numCols--;
          break;
          case UP:
          numRows++;
          break;
          case DOWN:
          if (numRows > 1)
              numRows--;
          break;
      }
      break;

      case 'f':
      selectInput( "Select an image", "readImageFromFile", new File(dataPath("data")) );
      break;

      case 'i':
      currentImage = INPUT;
      break;

      case 't':
      currentImage = OUTPUT;
      break;

      case 'h':
      applyHistogramThresholding();
      methodApplied = HISTO;
      currentImage = OUTPUT;
      break;

      case 'o':
      applyOtsusMethod();
      methodApplied = OTSU;
      currentImage = OUTPUT;
      break;

      case 'k':
      applyKMeansClustering();
      methodApplied = KMEANS;
      currentImage = OUTPUT;
      break;

      case '+':
      case '=':
      k++;
      applyKMeansClustering();
      methodApplied = KMEANS;
      currentImage = OUTPUT;
      break;

      case '-':
      case '_':
      if (k > 2) {
        k--;
        applyKMeansClustering();
        methodApplied = KMEANS;
        currentImage = OUTPUT;
    }
    break;

    case '?':
    println( " f   get image from file" );
    println( " i   show input image" );
    println( " t   show thresholded image" );
    println( " h   apply histogram thresholding" );
    println( " k   apply k-means thresholding" );
    println( " o   apply Otsu's method" );
    println( " +   increase k and apply k-means" );
    println( " -   decrease k and apply k-means" );
    println( " ?   help" );
    break;
}
}


// Read an image.

void readImageFromFile( File file ) {
    readImage( file.getPath() );
}

void readImage( String imageFilename ) {

    currentImage = INPUT;

    // Read the image

    image[INPUT] = loadImage( imageFilename );

    // Create a blank output image of the same size

    makeGreyOutputImage();

    // Remove the path from the filename (just so it's shorter when displayed)

    int i;
    for (i=imageFilename.length()-1; i>=0; i--)
        if (imageFilename.charAt(i) == '/' || imageFilename.charAt(i) == '\\')
            break;
        imageFilename = imageFilename.substring(i+1);
    }


// Create a grey output image as a placeholder

void makeGreyOutputImage()

{
    int w = image[INPUT].width;
    int h = image[INPUT].height;

    image[OUTPUT] = createImage( w, h, RGB );

    image[OUTPUT].loadPixels();

    for (int i=0; i<w*h; i++)
        image[OUTPUT].pixels[i] = color( 127, 127, 127 );

    image[OUTPUT].updatePixels();
}


// Store current thresholds

int numThresholds = 1;
int thresholds[] = new int[1];

void setNumThresholds( int n ) {
    numThresholds = n;
    thresholds = new int[n];
}


// Histogram thresholding

void applyHistogramThresholding()

{
    setNumThresholds(1);

    // Build the histogram of the image

    int histo[] = buildHistogram();

    // Apply iterative thresholding to minimize the "within-class sum of squares"

    int T = 127;
    int prevT;

    do {

        int sum1 = 0;
        int n1 = 0;
        for (int i=0; i<T; i++) {
            sum1 += histo[i] * i;
            n1 += histo[i];
        }

        float mean1 = sum1 / (float) n1;

        int sum2 = 0;
        int n2 = 0;
        for (int i=T; i<numPixelValues; i++) {
            sum2 += histo[i] * i;
            n2 += histo[i];
        }

        float mean2 = sum2 / (float) n2;

        prevT = T;

        T = (int) ((mean1 + mean2) / 2);

    } while (abs(T - prevT) > 1);

    // Show the thresholded image

    thresholds[0] = T;

    showThresholdedImage();
}


// Return a histogram of the input image

int[] buildHistogram()

{
    image[INPUT].loadPixels();
    
    int w = image[INPUT].width;
    int h = image[INPUT].height;

    int histo[] = new int[ numPixelValues ];
    for (int i=0; i<numPixelValues; i++)
        histo[i] = 0;

    for (int i=0; i<w*h; i++) {
        int p = (int) red( image[INPUT].pixels[i] ); // we'll assume red = greem = blue
        if (p > numPixelValues) p = numPixelValues-1;
        histo[p]++;
    }

    return histo;
}


// Create a thresholded output image using the global thresholds[]

void showThresholdedImage()

{
    // Find average values in each class (i.e. between each pair of adjacent thresholds)

    int avg[] = new int[numThresholds+1];

    int prevT = 0;
    for (int j=0; j<numThresholds; j++) {
        avg[j] = (prevT + thresholds[j])/2; // class j has greyscale = middle of class
        prevT = thresholds[j];
    }
    avg[numThresholds] = (prevT + numPixelValues)/2; 

    // For each pixel, determine its class and set its colour
    // appropriately in the output image.

    int w = image[INPUT].width;
    int h = image[INPUT].height;

    image[OUTPUT].loadPixels();

    for (int i=0; i<w*h; i++) {
        int p = (int) red(image[INPUT].pixels[i]);
        int j;
        for (j=0; j<numThresholds; j++) // find class = j
            if (p < thresholds[j])
                break;
        image[OUTPUT].pixels[i] = color( avg[j], avg[j], avg[j] ); // set colour for class j
    }

    image[OUTPUT].updatePixels();
}


// K-Means clustering
//
// Note that k = numThresholds+1.

int k = 3;

void applyKMeansClustering()

{
    setNumThresholds(k-1);

    // Build the histogram of the image

    int histo[] = buildHistogram();

    // Perform k-means

    // YOUR CODE HERE
    int[] T = new int[numThresholds];
    int[] U = new int[k];
    
    for (int i = 0; i < numThresholds; i++)
      T[i] = int(random(1, 254));
    T = sort(T);
    
    int deltaT;
    do {
      deltaT = 0;
      
      // Calculate new averages
      for (int i = 0; i < k; i++) {
        int startPoint = 0;
        int endPoint = 0;
        
        if (i == 0) {
          startPoint = 0;
          endPoint = T[i];
        }
        else if (i == k-1) {
          startPoint = T[i-1];
          endPoint = histo.length;
        }
        else {
          startPoint = T[i - 1];
          endPoint = T[i];
        }
        
        System.out.println("Start: " + startPoint + "\nEnd: " + endPoint);
        System.out.println("");
        
        int numPixels = 0;
        int numerator = 0;
        for (int x = startPoint; x < endPoint; x++) {
          numPixels += histo[x];
          numerator += histo[x] * x;
        }
        
        U[i] = numerator / numPixels;
      } // end calculate new averages
      
      // Update thresholds
      for (int t = 0; t < numThresholds; t++) {
        int newT = (U[t] + U[t+1]) / 2; 
        deltaT += abs(newT - T[t]);
        T[t] = newT;
      } // end update thresholds
      
    } while (deltaT > 0);
    
    // Show the thresholded image

    for (int i=0; i<k-1; i++) 
        thresholds[i] = T[i]; // YOUR CODE HERE

    showThresholdedImage();
}





// Otsu's method

int otsuThreshold;

void applyOtsusMethod()

{
    setNumThresholds(1);

    // Build the histogram of the image

    int histo[] = buildHistogram();

    // Perform Otsu's method

    // YOUR CODE HERE

    // Show the thresholded image

    thresholds[0] = 0;  // YOUR CODE HERE

    showThresholdedImage();
}