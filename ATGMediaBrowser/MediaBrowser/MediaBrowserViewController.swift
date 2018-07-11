//
//  MediaBrowserViewController.swift
//  Nisnass
//
//  Created by Suraj Thomas K on 7/10/18.
//  Copyright © 2018 Al Tayer Group LLC. All rights reserved.
//
//  Save to the extent permitted by law, you may not use, copy, modify,
//  distribute or create derivative works of this material or any part
//  of it without the prior written consent of Al Tayer Group LLC.
//  Any reproduction of this material must contain this notice.
//

public protocol MediaBrowserViewControllerDataSource: class {

    typealias CompletionBlock = (Int, UIImage?) -> Void

    func numberOfItems(in mediaBrowser: MediaBrowserViewController) -> Int
    func mediaBrowser(_ mediaBrowser: MediaBrowserViewController, imageAt index: Int, completion: @escaping CompletionBlock)
}

public protocol MediaBrowserViewControllerDelegate: class {

    func mediaBrowser(_ mediaBrowser: MediaBrowserViewController, didChangeFocusTo index: Int)
}

extension MediaBrowserViewControllerDelegate {

    func mediaBrowser(_ mediaBrowser: MediaBrowserViewController, didChangeFocusTo index: Int) {}
}

public class MediaBrowserViewController: UIViewController {

    public var gestureDirection: GestureDirection = .horizontal
    public var gapBetweenMediaViews: CGFloat = Constants.gapBetweenContents {
        didSet {
            MediaContentView.interItemSpacing = gapBetweenMediaViews
            contentViews.forEach({ $0.updateTransform() })
        }
    }
    public var browserStyle: BrowserStyle = .carousel
    public weak var dataSource: MediaBrowserViewControllerDataSource?
    public weak var delegate: MediaBrowserViewControllerDelegate?

    private enum Constants {

        static let gapBetweenContents: CGFloat = 50.0
        static let minimumVelocity: CGFloat = 15.0
        static let minimumTranslation: CGFloat = 0.1
        static let animationDuration: Double = 0.3
    }

    public enum GestureDirection {

        case horizontal
        case vertical
    }

    public enum BrowserStyle {

        case linear
        case carousel
    }

    private var contentViews: [MediaContentView] = []

    private var previousTranslation: CGPoint = .zero

    lazy private var panGestureRecognizer: UIPanGestureRecognizer = { [unowned self] in

        let gesture = UIPanGestureRecognizer()
        gesture.minimumNumberOfTouches = 1
        gesture.maximumNumberOfTouches = 1
        gesture.addTarget(self, action: #selector(panGestureEvent(_:)))
        return gesture
    }()

    private var numMediaItems: Int {
        return dataSource?.numberOfItems(in: self) ?? 1
    }

    // MARK: - Initializers
    public init() {

        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder aDecoder: NSCoder) {

        super.init(coder: aDecoder)
    }

    private func initialize() {

        view.backgroundColor = .red
    }

    override public func viewDidLoad() {

        super.viewDidLoad()

        populateContentViews()

        view.addGestureRecognizer(temporaryCloseGestureRecognizer)
        view.addGestureRecognizer(panGestureRecognizer)
    }

    override public func viewDidAppear(_ animated: Bool) {

        super.viewDidAppear(animated)

        contentViews.forEach({ $0.updateTransform() })
    }

    private func populateContentViews() {

        MediaContentView.interItemSpacing = gapBetweenMediaViews
        MediaContentView.contentTransformer = DefaultContentTransformers.horizontalMoveInOut

        contentViews.forEach({ $0.removeFromSuperview() })
        contentViews.removeAll()

        for i in -1...1 {
            let mediaView = MediaContentView(index: i)
            view.addSubview(mediaView)
            mediaView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                mediaView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                mediaView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                mediaView.topAnchor.constraint(equalTo: view.topAnchor),
                mediaView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])

            contentViews.append(mediaView)

            updateContents(of: mediaView)
        }
        view.bringSubview(toFront: contentViews[1])
    }

    // TODO: - Remove: Temporary Shit
    lazy private var temporaryCloseGestureRecognizer: UITapGestureRecognizer = { [unowned self] in

        let gesture = UITapGestureRecognizer()
        gesture.numberOfTapsRequired = 3
        gesture.addTarget(self, action: #selector(temporaryCloseMethod))
        return gesture
    }()

    @objc private func temporaryCloseMethod() {

        dismiss(animated: true, completion: nil)
    }
}

// MARK: - Pan Gesture Recognizer

extension MediaBrowserViewController {

    @objc private func panGestureEvent(_ recognizer: UIPanGestureRecognizer) {

        let translation = recognizer.translation(in: view)

        switch recognizer.state {
        case .began:
            previousTranslation = translation
        case .changed:
            moveViews(by: CGPoint(x: translation.x - previousTranslation.x, y: translation.y - previousTranslation.y))
        case .ended, .failed, .cancelled:
            let velocity = recognizer.velocity(in: view)

            var viewsCopy = contentViews
            let previousView = viewsCopy.removeFirst()
            let middleView = viewsCopy.removeFirst()
            let nextView = viewsCopy.removeFirst()

            var toMove: CGFloat = 0.0
            let directionalVelocity = gestureDirection == .horizontal ? velocity.x : velocity.y

            if fabs(directionalVelocity) < Constants.minimumVelocity &&
                fabs(middleView.position) < Constants.minimumTranslation {
                toMove = -middleView.position
            } else if directionalVelocity < 0.0 {
                if middleView.position >= 0.0 {
                    toMove = -middleView.position
                } else {
                    toMove = -nextView.position
                }
            } else {
                if middleView.position <= 0.0 {
                    toMove = -middleView.position
                } else {
                    toMove = -previousView.position
                }
            }

            UIView.animate(withDuration: Constants.animationDuration) { [weak self] in
                self?.contentViews.forEach({ $0.position += toMove })
            }
        default:
            break
        }

        previousTranslation = translation
    }
}

// MARK: - Updating View Positions

extension MediaBrowserViewController {

    private func moveViews(by translation: CGPoint) {

        let isGestureHorizontal = (gestureDirection == .horizontal)

        let viewSizeIncludingGap = CGSize(
            width: view.frame.size.width + gapBetweenMediaViews,
            height: view.frame.size.height + gapBetweenMediaViews
        )

        let normalizedTranslation = calculateNormalizedTranslation(
            translation: translation,
            viewSize: viewSizeIncludingGap
        )
        contentViews.forEach({
            $0.position += isGestureHorizontal ? normalizedTranslation.x : normalizedTranslation.y
        })

        var viewsCopy = contentViews
        let previousView = viewsCopy.removeFirst()
        let middleView = viewsCopy.removeFirst()
        let nextView = viewsCopy.removeFirst()

        let viewSize = isGestureHorizontal ? viewSizeIncludingGap.width : viewSizeIncludingGap.height
        let normalizedGap = gapBetweenMediaViews/viewSize
        let normalizedCenter = (middleView.frame.size.width / viewSize) * 0.5
        let viewCount = contentViews.count

        if middleView.position < -(normalizedGap + normalizedCenter) {

            // Previous item is taken and placed on right/down most side
            previousView.position += CGFloat(viewCount)
            previousView.index += viewCount
            updateContents(of: previousView)

            contentViews.removeFirst()
            contentViews.append(previousView)

            delegate?.mediaBrowser(self, didChangeFocusTo: contentViews[1].index)

        } else if middleView.position > (1 + normalizedGap - normalizedCenter) {

            // Next item is taken and placed on left/top most side
            nextView.position -= CGFloat(viewCount)
            nextView.index -= viewCount
            updateContents(of: nextView)

            contentViews.removeLast()
            contentViews.insert(nextView, at: 0)

            delegate?.mediaBrowser(self, didChangeFocusTo: contentViews[1].index)
        }
    }

    private func calculateNormalizedTranslation(translation: CGPoint, viewSize: CGSize) -> CGPoint {

        let middleView = contentViews[1]

        var normalizedTranslation = CGPoint(
            x: (translation.x)/viewSize.width,
            y: (translation.y)/viewSize.height
        )

        if browserStyle != .carousel {
            let isGestureHorizontal = (gestureDirection == .horizontal)
            let directionalTranslation = isGestureHorizontal ? normalizedTranslation.x : normalizedTranslation.y
            if (middleView.index == 0 && ((middleView.position + directionalTranslation) > 0.0)) ||
                (middleView.index == (numMediaItems - 1) && (middleView.position + directionalTranslation) < 0.0) {
                if isGestureHorizontal {
                    normalizedTranslation.x = -middleView.position
                } else {
                    normalizedTranslation.y = -middleView.position
                }
            }
        }
        return normalizedTranslation
    }

    private func updateContents(of contentView: MediaContentView) {

        contentView.image = nil
        let convertedIndex = abs(contentView.index) % numMediaItems
        dataSource?.mediaBrowser(self, imageAt: convertedIndex, completion: { (index, image) in

            if convertedIndex == index && image != nil {
                contentView.image = image
            }
        })
    }
}