//
//  FlowLayout.swift
//  
//
//  Created by Арсений Токарев on 04.10.2022.
//

import UIKit

internal final class FlowLayout<Section: Hashable, Item: Hashable>: UICollectionViewFlowLayout {
    public weak var grid: Grid.Manager<Section, Item>?
    
    internal override func targetContentOffset(
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
        guard let collectionView, let grid, let parent = grid.parent else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
        }
        guard let section = parent.source.section(for: grid._section),
              let style = parent.layout.style(for: section)
        else {
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
        }
        switch style {
        case .horizontal(_, _, let rows, _):
            switch rows {
            case .finite(_, let scrolling), .infinite(let scrolling):
                switch scrolling {
                case .centerted:
                    return result(collectionView: collectionView, forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
                default:
                    return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
                }
            }
        default:
            return super.targetContentOffset(forProposedContentOffset: proposedContentOffset, withScrollingVelocity: velocity)
        }
    }
    
    private func result(
        collectionView: UICollectionView,
        forProposedContentOffset proposedContentOffset: CGPoint,
        withScrollingVelocity velocity: CGPoint
    ) -> CGPoint {
        // Identify the layoutAttributes of cells in the vicinity of where the scroll view will come to rest
        let targetRect = CGRect(origin: proposedContentOffset, size: collectionView.bounds.size)
        let visibleCellsLayoutAttributes = layoutAttributesForElements(in: targetRect)

        // Translate those cell layoutAttributes into potential (candidate) scrollView offsets
        let candidateOffsets: [CGFloat]? = visibleCellsLayoutAttributes?.map({ cellLayoutAttributes in
            if #available(iOS 11.0, *) {
                return cellLayoutAttributes.frame.origin.x - collectionView.contentInset.left - collectionView.safeAreaInsets.left - sectionInset.left
            } else {
                return cellLayoutAttributes.frame.origin.x - collectionView.contentInset.left - sectionInset.left
            }
        })

        // Now we need to work out which one of the candidate offsets is the best one
        let bestCandidateOffset: CGFloat

        if velocity.x > 0 {
            // If the scroll velocity was POSITIVE, then only consider cells/offsets to the RIGHT of the proposedContentOffset.x
            // Of the cells/offsets to the right, the NEAREST is the `bestCandidate`
            // If there is no nearestCandidateOffsetToLeft then we default to the RIGHT-MOST (last) of ALL the candidate cells/offsets
            //      (this handles the scenario where the user has scrolled beyond the last cell)
            let candidateOffsetsToRight = candidateOffsets?.toRight(ofProposedOffset: proposedContentOffset.x)
            let nearestCandidateOffsetToRight = candidateOffsetsToRight?.nearest(toProposedOffset: proposedContentOffset.x)
            bestCandidateOffset = nearestCandidateOffsetToRight ?? candidateOffsets?.last ?? proposedContentOffset.x
        }
        else if velocity.x < 0 {
            // If the scroll velocity was NEGATIVE, then only consider cells/offsets to the LEFT of the proposedContentOffset.x
            // Of the cells/offsets to the left, the NEAREST is the `bestCandidate`
            // If there is no nearestCandidateOffsetToLeft then we default to the LEFT-MOST (first) of ALL the candidate cells/offsets
            //      (this handles the scenario where the user has scrolled beyond the first cell)
            let candidateOffsetsToLeft = candidateOffsets?.toLeft(ofProposedOffset: proposedContentOffset.x)
            let nearestCandidateOffsetToLeft = candidateOffsetsToLeft?.nearest(toProposedOffset: proposedContentOffset.x)
            bestCandidateOffset = nearestCandidateOffsetToLeft ?? candidateOffsets?.first ?? proposedContentOffset.x
        }
        else {
            // If the scroll velocity was ZERO we consider all `candidate` cells (regarless of whether they are to the left OR right of the proposedContentOffset.x)
            // The cell/offset that is the NEAREST is the `bestCandidate`
            let nearestCandidateOffset = candidateOffsets?.nearest(toProposedOffset: proposedContentOffset.x)
            bestCandidateOffset = nearestCandidateOffset ??  proposedContentOffset.x
        }
        let padding: CGFloat = {
            guard let indexPath = collectionView.indexPathForItem(at: CGPoint(x: bestCandidateOffset, y: collectionView.frame.height/2)),
                  let width = collectionView.cellForItem(at: indexPath)?.bounds.size.width
            else { return .zero }
            return max(0, (collectionView.frame.width-width)/2)
        }()
        return CGPoint(x: bestCandidateOffset-padding, y: proposedContentOffset.y)
    }

}

fileprivate extension Sequence where Iterator.Element == CGFloat {
    func toLeft(ofProposedOffset proposedOffset: CGFloat) -> [CGFloat] {
        return filter() { candidateOffset in
            return candidateOffset < proposedOffset
        }
    }

    func toRight(ofProposedOffset proposedOffset: CGFloat) -> [CGFloat] {
        return filter() { candidateOffset in
            return candidateOffset > proposedOffset
        }
    }

    func nearest(toProposedOffset proposedOffset: CGFloat) -> CGFloat? {
        guard let firstCandidateOffset = first(where: { _ in true }) else {
            return nil
        }

        return reduce(firstCandidateOffset) { (bestCandidateOffset: CGFloat, candidateOffset: CGFloat) -> CGFloat in
            let candidateOffsetDistanceFromProposed = abs(candidateOffset - proposedOffset)
            let bestCandidateOffsetDistancFromProposed = abs(bestCandidateOffset - proposedOffset)

            if candidateOffsetDistanceFromProposed < bestCandidateOffsetDistancFromProposed {
                return candidateOffset
            }
            
            return bestCandidateOffset
        }
    }
}
