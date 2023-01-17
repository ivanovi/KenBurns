import Foundation
import UIKit
import CalmParametricAnimations
import Kingfisher

/* 
 * a view that performs the Ken Burns effect on an image
 * see here: https://en.wikipedia.org/wiki/Ken_Burns_effect
 * http://www.twangnation.com/blog/http://example.com/uploads/2014/01/kenburns_portrait.jpg
 */

public struct DurationRange {
	let min: Double
	let max: Double
}

class KenBurnsAnimation : Equatable {
    unowned var targetImage: UIImageView

    var startTime: TimeInterval
    var duration: TimeInterval = 0

    let offsets: (x: Double, y: Double)
    let zoom: Double

    let fadeOutDuration: TimeInterval = 1.0

    var completion: ((_ animation: KenBurnsAnimation) -> ())?
    var willFadeOut: ((_ animation: KenBurnsAnimation) -> ())?

    init(targetImage: UIImageView, zoomIntensity: Double, durationRange: DurationRange?, pansAcross: Bool) {
        self.targetImage = targetImage

		if let durationRange {
			duration = Random.double(durationRange.min, durationRange.max)
		}

        startTime = CACurrentMediaTime()

        let zoomMin = 1 + (0.3 * zoomIntensity)
        let zoomMax = 1 + (1.4 * zoomIntensity)
        zoom = Random.double(zoomMin, zoomMax)

        /* zooms to within maximal square within bounds that won't expose the edge of the image */
        let range = (min: (1 - zoom), max: 0.0)
        if pansAcross {
            offsets = (
                x: range.min,
                y: Random.double(0.3 * range.min, 0.7 * range.min)
            )
        } else {
            offsets = (
                x: Random.double(range.min, range.max),
                y: Random.double(range.min, range.max)
            )
        }
    }

    var timeRemaining: TimeInterval {
        return (1 - progress) * duration
    }
    
    var progress: Double {
		guard duration > 0 else { return 1 }
        return (CACurrentMediaTime() - startTime) / duration
    }

    var progressCurved: Double {
		guard duration > 0 else { return 1 }
		return kParametricTimeBlockAppleOut(progress)
    }

    var currentZoom: Double {
        return progressCurved * (zoom - 1) + 1
    }

    var currentAlpha: CGFloat {
        if timeRemaining > fadeOutDuration {
            return 1.0
        }
        return CGFloat(timeRemaining / fadeOutDuration)
    }

    func currentPosition(_ width: CGFloat, _ height: CGFloat) -> CGPoint {
        return CGPoint(x: width * CGFloat(progressCurved * offsets.x),
                       y: height * CGFloat(progressCurved * offsets.y))
    }

    func update(_ width: CGFloat, _ height: CGFloat) {
        targetImage.alpha = currentAlpha
        targetImage.position = currentPosition(width, height)
        let zoom = CGFloat(currentZoom)
        targetImage.transform = CGAffineTransform(scaleX: zoom, y: zoom)

        callWillFadeOutIfNecessary()
        callCompletionIfNecessary()
    }

    func callWillFadeOutIfNecessary() {
        if timeRemaining > fadeOutDuration {
            return
        }
        guard let willFadeOut = self.willFadeOut else { return }
        willFadeOut(self)
        self.willFadeOut = nil // never call it again
    }
    
    func forceFadeOut() {
        self.duration = CACurrentMediaTime() - startTime + fadeOutDuration
    }

    func callCompletionIfNecessary() {
        if timeRemaining > 0 {
            return
        }
        guard let completion = self.completion else { return }
        completion(self)
        self.completion = nil // never call it again
    }
}

func ==(lhs: KenBurnsAnimation, rhs: KenBurnsAnimation) -> Bool {
    return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}

public protocol KenBurnsImageDelegate: AnyObject {
	func animationDidFinish(completedIndex: Int, nextDuration: Double)
}

@objc public class KenBurnsImageView: UIView {

	private class AnimationHandler: NSObject {
		var handler: () -> Void

		init(handler: @escaping () -> Void) {
			self.handler = handler
			super.init()
		}

		@objc func handleAnimation() {
			handler()
		}
	}

    public var loops = true
    public var pansAcross = false
    public var zoomIntensity = 1.0
    public var durationRange = DurationRange(min: 10, max: 20)

    public var isAnimating: Bool {
        return !animations.isEmpty
    }
    
    lazy var currentImageView: UIImageView = {
        return self.newImageView()
    }()

    lazy var nextImageView: UIImageView = {
        return self.newImageView()
    }()
    
    lazy var updatesDisplayLink: CADisplayLink = {

		let handler = AnimationHandler { [weak self] in
			self?.updateAllAnimations()
		}
		return CADisplayLink(target: handler,
							 selector: #selector(AnimationHandler.handleAnimation))
    }()

    var animations: [KenBurnsAnimation] = []
    var timeAtPause: CFTimeInterval = 0
    var completed : (() -> Void)?
    
    var imageQueue : RingBuffer<UIImage>? = nil
    var imageURLs : RingBuffer<URL>? = nil
    var imagePlaceholders : RingBuffer<UIImage>? = nil

	public weak var delegate: KenBurnsImageDelegate?

    var index = -1
    private var remoteQueue = false
	private var bufferedURLs = [URL]()

    public init() {
        super.init(frame: .zero)

        isUserInteractionEnabled = false
        clipsToBounds = true

        addSubview(nextImageView)
        addSubview(currentImageView)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    public override func awakeFromNib() {
        super.awakeFromNib()
        
        isUserInteractionEnabled = false
        clipsToBounds = true
        
        nextImageView.kf.indicatorType = .activity
        currentImageView.kf.indicatorType = .activity
        
        addSubview(nextImageView)
        addSubview(currentImageView)
    }

    private func setImage(_ image: UIImage) {
        index = -1
        currentImageView.image = image
        nextImageView.image = image
    }

    private func fetchImage(_ url: URL, placeholder: UIImage?) {
        [ currentImageView, nextImageView ].forEach {
            $0.kf.setImage(with: url, placeholder: placeholder, options: [.transition(.fade(0.2))])
        }
    }

    // Swift can set durationRange directly, but objc needs this method to modify tuple
    public func setDuration(min: Double, max: Double) {
        self.durationRange = DurationRange(min: min, max: max)
    }

    private func newImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        return imageView
    }

    public func startAnimating() {
        if isAnimating {
            return
        }

        updatesDisplayLink.add(to: RunLoop.main, forMode: .common)
		startNewAnimation(durationRange: nil)
    }

    public func setImageQueue(withUrls urls:[URL]) {
		guard urls != bufferedURLs else { return }

        remoteQueue = true
        self.imageURLs = RingBuffer<URL>(count: urls.count)
        
        for u in urls {
            self.imageURLs?.write(u)
        }
        
        self.fetchImage(self.imageURLs!.read()!, placeholder: nil)
		bufferedURLs = urls
        
        index = 0

        queueNextImage()
    }

    public func stopAnimating() {
        [ currentImageView, nextImageView ].forEach {
            $0.layer.removeAllAnimations()
            $0.alpha = 1
            $0.transform = CGAffineTransform.identity
            $0.size = self.size
            $0.position = .zero
        }

        if !isAnimating {
            return
        }

        animations.removeAll()
        updatesDisplayLink.remove(from: RunLoop.main, forMode: .common)
    }
    
    public func pause()  {
        updatesDisplayLink.isPaused = true
        // Save the time so we can resume the animation from where we left of.
        timeAtPause = layer.convertTime(CACurrentMediaTime(), from: nil)
    }
    
    public func resume() {
        let timeSincePause = layer.convertTime(CACurrentMediaTime(), from: nil) - timeAtPause
        // Add the elapsed time since pause to startTime, so the progress is caculated from where we left off.
        animations.forEach { $0.startTime += timeSincePause }
        updatesDisplayLink.isPaused = false
    }

	private func startNewAnimation(durationRange: DurationRange?) {
        currentImageView.transform = CGAffineTransform.identity
        currentImageView.size = self.size
        let animation = KenBurnsAnimation(targetImage: currentImageView,
										  zoomIntensity: zoomIntensity,
										  durationRange: durationRange,
										  pansAcross: pansAcross)
		animation.completion = { [weak self] a in
			self?.didFinishAnimation(a)
		}
		animation.willFadeOut = { [weak self] a in
			self?.willFadeOutAnimation(a)
		}
        animations.append(animation)
    }

    @objc private func updateAllAnimations() {
        animations.forEach {
            $0.update(self.w, self.h)
        }
    }

	private func didFinishAnimation(_ animation: KenBurnsAnimation) {
        animations.remove(animation)
        queueNextImage()

		let imagesIdx = imageURLs?.index ?? 0
		let imagesCount = imageURLs?.count ?? 0
		let completedIdx = imagesCount > 0 ? max(imagesIdx - 2, 0) % imagesCount : 0
		delegate?.animationDidFinish(completedIndex: completedIdx,
									 nextDuration: animations.first?.duration ?? 0)
    }
    
	private func nextImage() {
        animations[0].forceFadeOut()
    }

	private func willFadeOutAnimation(_ animation: KenBurnsAnimation) {
        swapCurrentAndNext()
		startNewAnimation(durationRange: durationRange)
    }
    
	private func queueNextImage() {
		if remoteQueue, imageURLs?.isEmpty == Optional(false)  {
			nextImageView.kf.setImage(with: imageURLs!.read()!,
									  placeholder: nil,
									  options: [.transition(.fade(0.2))])
			nextImageView.kf.indicatorType = .activity
		} else if imageQueue != nil {
			nextImageView.image = imageQueue!.read() // force unwrap required as .read() mutates the queue
		} else {
			nextImageView.image = currentImageView.image
		}
	}

	private func swapCurrentAndNext() {
        bringSubviewToFront(currentImageView)
        insertSubview(nextImageView, belowSubview: currentImageView)

        let temp = currentImageView
        currentImageView = nextImageView
        nextImageView = temp
           
    }
}
