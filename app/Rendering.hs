{-# LANGUAGE NoMonomorphismRestriction, FlexibleContexts, TypeFamilies #-}

module Rendering (
  Drawing(..),
  portToPort,
  iconToPort,
  iconToIcon,
  toNames,
  renderDrawing
) where

import Diagrams.Prelude
import Diagrams.TwoD.GraphViz
import Diagrams.Backend.SVG(B)

import Data.GraphViz
--import qualified Data.GraphViz.Attributes.Complete as GVA
--import Data.GraphViz.Commands
import Data.Map((!))
import Data.Maybe (fromMaybe)

import Icons

-- | An Edge has an name of the source icon, and its optional port number,
-- and the name of the destination icon, and its optional port number.
type Edge = (Name, Maybe Int, Name, Maybe Int)

-- | A drawing is a map from names to Icons, a list of edges,
-- and a map of names to subDrawings
data Drawing = Drawing [(Name, Icon)] [Edge] [(Name, Drawing)]

-- | Convert a map of names and icons, to a list of names and diagrams.
-- The subDiagramMap
makeNamedMap :: IsName name => [(Name, Diagram B)] -> [(name, Icon)] -> [(name, Diagram B)]
makeNamedMap subDiagramMap =
  map (\(name, icon) -> (name, iconToDiagram icon subDiagramMap # nameDiagram name))

mapFst :: (a -> b) -> [(a, c)] -> [(b, c)]
mapFst f = map (\(x, y) -> (f x, y))

toNames :: (IsName a) => [(a, b)] -> [(Name, b)]
toNames = mapFst toName

portToPort :: (IsName a, IsName c) => a -> b -> c -> d -> (Name, Maybe b, Name, Maybe d)
portToPort a b c d = (toName a, Just b, toName c, Just d)

iconToPort :: (IsName a, IsName c) => a -> c -> d -> (Name, Maybe b, Name, Maybe d)
iconToPort a   c d = (toName a, Nothing, toName c, Just d)

iconToIcon :: (IsName a, IsName c) => a -> c -> (Name, Maybe b, Name, Maybe d)
iconToIcon a   c   = (toName a, Nothing, toName c, Nothing)

edgesToGraph names edges = mkGraph names simpleEdges
  where
    simpleEdges = map (\(a, _, c, _) -> (a, c, ())) edges

uncurry4 f (a, b, c, d) = f a b c d

makeConnections edges = applyAll connections
  where
    connections = map (uncurry4 connectMaybePorts) edges

placeNodes scaleFactor layoutResult nameDiagramMap = mconcat placedNodes
  where
    (positionMap, _) = getGraph layoutResult
    placedNodes = map placeNode nameDiagramMap
    placeNode (name, diagram) = place diagram (scaleFactor *^ (positionMap ! name))

doGraphLayout scaleFactor graph nameDiagramMap connectNodes = do
  layoutResult <- layoutGraph Neato graph
  return $ placeNodes scaleFactor layoutResult nameDiagramMap # connectNodes

renderDrawing (Drawing nameIconMap edges subDrawings) scaleFactor = do
  subDiagramMap <- mapM subDrawingMapper subDrawings
  let diagramMap = makeNamedMap subDiagramMap nameIconMap
  --mapM_ (putStrLn . (++"\n") . show . (map fst) . names . snd) diagramMap
  doGraphLayout scaleFactor (edgesToGraph iconNames edges) diagramMap (makeConnections edges)
  where
    iconNames = map fst nameIconMap
    subDrawingMapper (name, subDrawing) = do
      subDiagram <- renderDrawing subDrawing (0.2 * scaleFactor)
      return (name, subDiagram)