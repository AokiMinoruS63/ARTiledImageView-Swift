//
//  ARTiledImageScrollView.swift
//

import SDWebImage

private let ARTiledImageScrollViewDefaultZoomStep: CGFloat = 1.5

class ARTiledImageScrollView: UIScrollView, UIScrollViewDelegate {
    /// Current tile zoom level.
    var tileZoomLevel: Int = 1
    /// The data source for image.
    private var dataSourceEntity: (ARTiledImageViewDataSource & NSObjectProtocol)!
    /// Display tile borders, usually for debugging purposes.
    private var displayTileBordersEntity: Bool?
    /// Set a background image, displayed while tiles are being downloaded.
    private var backgroundImageURLEntity: URL? = nil
    
    /// Set a background image, displayed while tiles are being downloaded.
    private var backgroundImageEntity: UIImage? = nil
    /// Point on which to center the map by default, removed when panned.
    var centerPoint: CGPoint = .zero
    /// Size of the view, typically the full size of the background image.
    var originalSize: CGSize = .zero
    /// The data source for image.
    var zoomStep: CGFloat = 0.0
    
    private(set) var tiledImageView: ARTiledImageView!
    private(set) var backgroundImageView: UIImageView!
    
    
    override var frame: CGRect {
        get{
            super.frame
        }
        set {
            super.frame = newValue
            let zoomedOut = self.zoomScale == self.minimumZoomScale
            if (!__CGPointEqualToPoint(self.centerPoint, .zero) && !zoomedOut) {
                self.center(on: self.centerPoint, animated: false)
             }
        }
    }

    var dataSource: (ARTiledImageViewDataSource & NSObjectProtocol)! {
        get {
            dataSourceEntity
        }
        set {
            dataSourceEntity = newValue
            setup()
        }
    }
    
    var displayTileBorders: Bool {
        get {
            displayTileBordersEntity ?? false
        }
        set {
            if displayTileBordersEntity == nil {
                displayTileBordersEntity = newValue
                self.tiledImageView.displayTileBorders = newValue
            }
        }
    }
    
    var backgroundImageURL: URL! {
        get {
            backgroundImageURLEntity
        }
        set {
            backgroundImageView = UIImageView(frame: self.tiledImageView.frame)
            self.insertSubview(backgroundImageView, belowSubview: self.tiledImageView)
            backgroundImageView.sd_setImage(with: backgroundImageURL)
            if backgroundImageURLEntity == nil {
                backgroundImageURLEntity = newValue
            }
        }
    }
    
    var backgroundImage: UIImage! {
        get {
            backgroundImageEntity
        }
        set {
            backgroundImageView = UIImageView(frame: self.tiledImageView.frame)
            self.insertSubview(backgroundImageView, belowSubview: self.tiledImageView)
            backgroundImageView.image = backgroundImage
            if backgroundImageEntity == nil {
                backgroundImageEntity = newValue
            }
        }
    }
    
    private func setup() {
        setTiledImageView()
        self.addSubview(self.tiledImageView)
        self.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.delegate = self
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap))
        doubleTap.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTap)
        
        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap))
        twoFingerTap.numberOfTouchesRequired = 2
        self.addGestureRecognizer(twoFingerTap)
        
        self.panGestureRecognizer.addTarget(self, action: #selector(mapPanGestureHandler))
    }
    
    private func setTiledImageView() {
        tiledImageView = ARTiledImageView(dataSource: self.dataSource)
    }
    private func setMaxMinZoomScalesForCurrentBounds() {
        let boundsSize = self.bounds.size
        let imageSize = self.dataSource.imageSize(for: nil)
        
        // Calculate min/max zoomscale.
        let xScale = boundsSize.width / imageSize.width; // the scale needed to perfectly fit the image width-wise
        let yScale = boundsSize.height / imageSize.height; // the scale needed to perfectly fit the image height-wise
        var minScale = max(xScale, yScale); // use minimum of these to allow the image to become fully visible
        let maxScale: CGFloat = 1.0
        
        // Don't let minScale exceed maxScale.
        // If the image is smaller than the screen, we don't want to force it to be zoomed.
        if (minScale > maxScale) {
            minScale = maxScale
        }
        
        self.maximumZoomScale = maxScale * 0.6
        self.minimumZoomScale = minScale

        self.originalSize = imageSize
        self.contentSize = boundsSize
    }
    
    /// Convert a point at full zoom scale to the same one at the current zoom scale.
    func zoomRelativePoint(point: CGPoint) -> CGPoint {
        
         let x = (self.contentSize.width / self.originalSize.width) * point.x;
         let y = (self.contentSize.height / self.originalSize.height) * point.y;
        return CGPoint(x: round(x), y: round(y));
         
    }
    /// Center image on a given point.
    func center(on point: CGPoint, animated: Bool) {
        let x = (point.x * self.zoomScale) - (self.frame.size.width / 2.0);
        let y = (point.y * self.zoomScale) - (self.frame.size.height / 2.0);
        self.setContentOffset(CGPoint(x: round(x), y: round(y)), animated: animated)
        centerPoint = point;
    }
    
    /// Zoom the image to fit the current display.
    func zoomToFit(animate: Bool) {
        self.setZoomScale(self.minimumZoomScale, animated: animate)
    }
    
    /// Callback for when the tile zoom level has changed.
    private func tileZoomLevelDidChange() {
        
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        
         self.backgroundImageView.frame = self.tiledImageView.frame;
         if (self.tileZoomLevel != self.tiledImageView.currentZoomLevel) {
             tileZoomLevel = self.tiledImageView.currentZoomLevel;
            self.tileZoomLevelDidChange()
         }
         
    }
    
    @objc private func mapPanGestureHandler(panGesture: UIPanGestureRecognizer!)
    {
        if (panGesture.state == UIGestureRecognizer.State.began) {
            centerPoint = .zero
        }
    }
    
    /// MARK - UIScrollViewDelegate
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        self.tiledImageView
    }
    
    private var zoomLevel: CGFloat {
        self.zoomScale / self.maximumZoomScale
    }
    
    /// MARK - Tap to Zoom
    
    @objc private func handleDoubleTap(_ gestureRecognizer: UIGestureRecognizer!) {
         // Double tap zooms in, but returns to normal zoom level if it reaches max zoom.
         if (self.zoomScale >= self.maximumZoomScale) {
            self.setZoomScale(self.minimumZoomScale, animated: true)
         } else {
             // The location tapped becomes the new center
            let tapCenter = gestureRecognizer.location(in: self.tiledImageView)
            
             let newScale = min(self.zoomScale * (self.zoomStep ?? ARTiledImageScrollViewDefaultZoomStep), self.maximumZoomScale)
            let maxZoomRect = self.rectAroundPoint(tapCenter, atZoomScale: newScale)
            self.zoom(to: maxZoomRect, animated: true)
             
         }
    }
    
    private func rectAroundPoint(_ point: CGPoint, atZoomScale zoomScale: CGFloat) -> CGRect {
         // Define the shape of the zoom rect.
         let boundsSize = self.bounds.size;

         // Modify the size according to the requested zoom level.
         // For example, if we're zooming in to 0.5 zoom, then this will increase the bounds size by a factor of two.
        let scaledBoundsSize = CGSize(width: boundsSize.width / zoomScale, height: boundsSize.height / zoomScale);

        return CGRect(x: point.x - scaledBoundsSize.width / 2,
                      y: point.y - scaledBoundsSize.height / 2,
                      width: scaledBoundsSize.width,
                      height: scaledBoundsSize.height);
    }
    
    @objc private func handleTwoFingerTap(_ gestureRecognizer: UIGestureRecognizer!) {
         // Two-finger tap zooms out, but returns to normal zoom level if it reaches min zoom.
         let newScale = self.zoomScale <= self.minimumZoomScale ? self.maximumZoomScale : self.zoomScale / (self.zoomStep ?? ARTiledImageScrollViewDefaultZoomStep)
        self.setZoomScale(newScale, animated: true)
    }
}
