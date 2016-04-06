{-# LANGUAGE NoMonomorphismRestriction, FlexibleContexts, TypeFamilies, RankNTypes, PartialTypeSignatures #-}
module Icons
    (
    Icon(..),
    applyADia,
    flatLambda,
    iconToDiagram,
    nameDiagram,
    textBox,
    enclosure,
    lambdaRegion,
    resultIcon,
    guardIcon,
    caseIcon,
    defaultLineWidth,
    ColorStyle(..),
    colorScheme,

    nestedApplyDia
    ) where

import Diagrams.Prelude
-- import Diagrams.Backend.SVG(B)
import Diagrams.TwoD.Text(Text)
import Data.Typeable(Typeable)

import Types(Icon(..), SpecialQDiagram, SpecialBackend)
import Util(fromMaybeError)
import DrawingColors(colorScheme, ColorStyle(..))

-- TYPES --
type TransformableDia b = (Bool -> Double -> SpecialQDiagram b)

-- COLORS --
lineCol :: Colour Double
lineCol = lineC colorScheme

-- FUNCTIONS --
-- Optimization: The apply0NDia's can be memoized.
iconToDiagram :: SpecialBackend b => Icon -> [(Name, SpecialQDiagram b)] -> TransformableDia b
iconToDiagram (ApplyAIcon n) _ = identDiaFunc $ applyADia n
iconToDiagram (PAppIcon n str) _ = pAppDia n str
iconToDiagram (TextApplyAIcon n str) _ = textApplyADia n str
iconToDiagram ResultIcon _ = identDiaFunc resultIcon
iconToDiagram BranchIcon _ = identDiaFunc branchIcon
iconToDiagram (TextBoxIcon s) _ = identDiaFunc $ textBox s
iconToDiagram (BindTextBoxIcon s) _ = identDiaFunc $ bindTextBox s
iconToDiagram (GuardIcon n) _ = identDiaFunc $ guardIcon n
iconToDiagram (CaseIcon n) _ = identDiaFunc $ caseIcon n
iconToDiagram CaseResultIcon _ = identDiaFunc caseResult
iconToDiagram (FlatLambdaIcon n) _ = identDiaFunc $ flatLambda n
iconToDiagram (NestedApply s args) _ = nestedApplyDia s args
iconToDiagram (LambdaRegionIcon n diagramName) nameToSubdiagramMap =
  identDiaFunc $ lambdaRegion n dia
  where
    dia = fromMaybeError "iconToDiagram: subdiagram not found" $ lookup diagramName nameToSubdiagramMap

-- Make an identity TransformableDia
identDiaFunc :: SpecialQDiagram b -> TransformableDia b
identDiaFunc dia _ _ = dia

-- | Names the diagram and puts all sub-names in the namespace of the top level name.
nameDiagram :: (SpecialBackend b, IsName nm) => nm -> SpecialQDiagram b -> SpecialQDiagram b
nameDiagram name dia = named name (name .>> dia)

-- | Make an port with an integer name. Always use <> to add a ports (not === or |||)
--- since mempty has no size and will not be placed where you want it.
makePort :: Int -> SpecialQDiagram b
makePort x = mempty # named x
--makePort x = circle 0.2 # fc green # named x
-- Note, the version of makePort below seems to have a different type.
--makePort x = textBox (show x) # fc green # named x

-- CONSTANTS --
defaultLineWidth :: (Fractional a) => a
defaultLineWidth = 0.15

-- APPLY0 ICON --
circleRadius :: (Fractional a) => a
circleRadius = 0.5

apply0Triangle ::
   (Typeable (N b), Transformable b, HasStyle b, TrailLike b,
      V b ~ V2) =>
     b
apply0Triangle = eqTriangle (2 * circleRadius) # rotateBy (-1/12) # lw none

portCircle :: (SpecialBackend b) => SpecialQDiagram b
portCircle = circle (circleRadius * 0.5) # fc lineCol # lw none

-- applyA Icon--
-- | apply0N port locations:
-- Port 0: Function
-- Port 1: Result
-- Ports 2,3..: Arguments
coloredApplyADia ::
  (SpecialBackend b) =>
  Colour Double -> Int -> SpecialQDiagram b
coloredApplyADia appColor n = finalDia # centerXY where
  seperation = circleRadius * 1.5
  trianglePortsCircle = hcat [
    reflectX (fc appColor apply0Triangle),
    hcat $ take n $ map (\x -> makePort x <> portCircle <> strutX seperation) [2,3..],
    makePort 1 <> alignR (circle circleRadius # fc appColor # lwG defaultLineWidth # lc appColor)
    ]
  allPorts = makePort 0 <> alignL trianglePortsCircle
  topAndBottomLineWidth = width allPorts - circleRadius
  topAndBottomLine = hrule topAndBottomLineWidth # lc appColor # lwG defaultLineWidth # alignL
  finalDia = topAndBottomLine === allPorts === topAndBottomLine

applyADia :: SpecialBackend b => Int -> SpecialQDiagram b
applyADia = coloredApplyADia (apply0C colorScheme)

textApplyADia :: SpecialBackend b =>
  Int -> String -> TransformableDia b
textApplyADia = generalTextAppDia (textBoxTextC colorScheme) (apply0C colorScheme)

pAppDia :: SpecialBackend b =>
  Int -> String -> TransformableDia b
pAppDia = generalTextAppDia (patternTextC colorScheme) (patternC colorScheme)

--Get the decimal part of a float
reduceAngleRange :: Double -> Double
reduceAngleRange x = x - fromInteger (floor x)

generalTextAppDia :: SpecialBackend b =>
  Colour Double -> Colour Double -> Int -> String -> Bool -> Double -> SpecialQDiagram b
generalTextAppDia textCol borderCol numArgs str reflect angle = rotateDia where
  rotateDia = transformCorrectedTextBox str textCol borderCol reflect angle |||
    coloredApplyADia borderCol numArgs

transformCorrectedTextBox :: SpecialBackend b =>
  String -> Colour Double -> Colour Double -> TransformableDia b
transformCorrectedTextBox str textCol borderCol reflect angle =
  rotateBy textBoxRotation (reflectIfTrue reflect (coloredTextBox textCol (opaque borderCol) str))
  where
    reducedAngle = reduceAngleRange angle
    textBoxRotation = if (reducedAngle > (1/4)) && (reducedAngle < (3/4)) then 1 / 2 else 0
    reflectIfTrue shouldReflect dia = if shouldReflect then reflectX dia else dia


nestedApplyDia :: SpecialBackend b =>
  String -> [Maybe (Name, Icon)] -> TransformableDia b
nestedApplyDia funText args reflect angle = transformedText ||| centerY finalDia
  where
    transformedText = transformCorrectedTextBox funText (textBoxTextC colorScheme) (apply0C colorScheme) reflect angle
    seperation = circleRadius * 1.5
    verticalSeperation = circleRadius
    appColor = apply0C colorScheme
    n = length args
    trianglePortsCircle = hsep seperation $
      reflectX (fc appColor apply0Triangle) :
      zipWith makeInnerIcon [2,3..] args ++
      [makePort 1 <> alignR (circle circleRadius # fc appColor # lwG defaultLineWidth # lc appColor)]

    allPorts = makePort 0 <> alignL trianglePortsCircle
    topAndBottomLineWidth = width allPorts - circleRadius
    argBox = rect topAndBottomLineWidth (height allPorts + verticalSeperation)# lc appColor # lwG defaultLineWidth # alignL
    finalDia = argBox <> allPorts

    makeInnerIcon portNum Nothing = makePort portNum <> portCircle
    makeInnerIcon portNum (Just (iconName, icon)) = nameDiagram iconName $ iconToDiagram icon [] reflect angle


-- TEXT ICON --
textBoxFontSize :: (Num a) => a
textBoxFontSize = 1
monoLetterWidthToHeightFraction :: (Fractional a) => a
monoLetterWidthToHeightFraction = 0.61
textBoxHeightFactor :: (Fractional a) => a
textBoxHeightFactor = 1.1

textBox :: SpecialBackend b =>
  String -> SpecialQDiagram b
textBox = coloredTextBox (textBoxTextC colorScheme) $ opaque (textBoxC colorScheme)

bindTextBox :: SpecialBackend b =>
  String -> SpecialQDiagram b
bindTextBox = coloredTextBox (bindTextBoxTextC colorScheme) $ opaque (bindTextBoxC colorScheme)

-- Since the normal SVG text has no size, some hackery is needed to determine
-- the size of the text's bounding box.
coloredTextBox :: SpecialBackend b =>
  Colour Double
  -> AlphaColour Double -> String -> SpecialQDiagram b
coloredTextBox textColor boxColor t =
  text t # fc textColor # font "freemono" # bold # fontSize (local textBoxFontSize)
  <> rect rectangleWidth (textBoxFontSize * textBoxHeightFactor) # lcA boxColor # lwG (0.6 * defaultLineWidth)
  where
    rectangleWidth = textBoxFontSize * monoLetterWidthToHeightFraction
      * fromIntegral (length t)
      + (textBoxFontSize * 0.2)

-- ENCLOSING REGION --
enclosure :: SpecialBackend b =>
  SpecialQDiagram b -> SpecialQDiagram b
enclosure dia = dia <> boundingRect (dia # frame 0.5) # lc (regionPerimC colorScheme) # lwG defaultLineWidth

-- LAMBDA ICON --
-- Don't use === here to put the port under the text box since mempty will stay
-- at the origin of the text box.
lambdaIcon ::
  SpecialBackend b =>
  Int -> SpecialQDiagram b
lambdaIcon x = coloredTextBox (lamArgResC colorScheme) transparent "λ" # alignB <> makePort x

-- LAMBDA REGION --

-- | lambdaRegion takes as an argument the numbers of parameters to the lambda,
-- and draws the diagram inside a region with the lambda icons on top.
lambdaRegion :: SpecialBackend b =>
  Int -> SpecialQDiagram b -> SpecialQDiagram b
lambdaRegion n dia =
  centerXY $ lambdaIcons # centerX === (enclosure dia # centerX)
  where lambdaIcons = hsep 0.4 (take n (map lambdaIcon [0,1..]))

-- RESULT ICON --
resultIcon :: SpecialBackend b => SpecialQDiagram b
resultIcon = unitSquare # lw none # fc (lamArgResC colorScheme)

-- BRANCH ICON --
branchIcon :: SpecialBackend b => SpecialQDiagram b
branchIcon = circle circleRadius # fc lineCol # lc lineCol # lw none

-- GUARD ICON --
guardSize :: (Fractional a) => a
guardSize = 0.7

guardTriangle :: SpecialBackend b =>
  Int -> SpecialQDiagram b
guardTriangle x =
  ((triangleAndPort ||| (hrule (guardSize * 0.8) # lwG defaultLineWidth)) # alignR) <> makePort x # alignL
  where
    triangleAndPort = polygon (with & polyType .~ PolySides [90 @@ deg, 45 @@ deg] [guardSize, guardSize])
      # rotateBy (1/8) # lwG defaultLineWidth # alignT # alignR

guardLBracket :: SpecialBackend b =>
  Int -> SpecialQDiagram b
guardLBracket x = ell # alignT # alignL <> makePort x
  where
    ellShape = fromOffsets $ map r2 [(0, guardSize), (-guardSize,0)]
    ell = ellShape # strokeLine # lc (boolC colorScheme) # lwG defaultLineWidth # lineJoin LineJoinRound

generalGuardIcon :: SpecialBackend b =>
  Colour Double -> (Int -> SpecialQDiagram b) -> SpecialQDiagram b -> Int -> SpecialQDiagram b
generalGuardIcon triangleColor lBracket bottomDia n = centerXY $ alignT (bottomDia <> makePort 1) <> alignB (bigVerticalLine <> guardDia <> makePort 0)
  where
    --guardTriangles = vsep 0.4 (take n (map guardTriangle [0,1..]))
    trianglesWithPorts = map guardTriangle [2,4..]
    lBrackets = map lBracket [3, 5..]
    trianglesAndBrackets =
      zipWith zipper trianglesWithPorts lBrackets
    zipper thisTriangle lBrack = verticalLine === ((lBrack # extrudeRight guardSize) # alignR <> (thisTriangle # alignL # lc triangleColor))
      where
        verticalLine = strutY 0.4
    guardDia = vcat (take n trianglesAndBrackets # alignT)
    bigVerticalLine = vrule (height guardDia) # lc triangleColor # lwG defaultLineWidth # alignT

-- | The ports of the guard icon are as follows:
-- Port 0: Top result port
-- Port 1: Bottom result port
-- Ports 3,5...: The left ports for the booleans
-- Ports 2,4...: The right ports for the values
guardIcon :: SpecialBackend b =>
  Int -> SpecialQDiagram b
guardIcon = generalGuardIcon lineCol guardLBracket mempty

-- TODO Improve design to be more than a circle.
caseResult :: SpecialBackend b =>
  SpecialQDiagram b
caseResult = circle (circleRadius * 0.7) # fc caseCColor # lc caseCColor # lw none where
  caseCColor = caseRhsC colorScheme

caseC :: SpecialBackend b =>
  Int -> SpecialQDiagram b
caseC n = caseResult <> makePort n


-- | The ports of the case icon are as follows:
-- Port 0: Top result port
-- Port 1: Bottom result port
-- Ports 3,5...: The left ports for the results
-- Ports 2,4...: The right ports for the patterns
caseIcon :: SpecialBackend b =>
  Int -> SpecialQDiagram b
caseIcon = generalGuardIcon (patternC colorScheme) caseC caseResult

-- | The ports of flatLambdaIcon are:
-- 0: Result icon
-- 1: The lambda function value
-- 2,3.. : The parameters
flatLambda :: SpecialBackend b => Int -> SpecialQDiagram b
flatLambda n = finalDia where
  lambdaCircle = circle circleRadius # fc (regionPerimC colorScheme) # lc (regionPerimC colorScheme) # lwG defaultLineWidth
  lambdaParts = (makePort 0 <> resultIcon) : (portIcons ++  [makePort 1 <> alignR lambdaCircle])
  portIcons = take n $ map (\x -> makePort x <> portCircle) [2,3..]
  middle = alignL (hsep 0.5 lambdaParts)
  topAndBottomLineWidth = width middle - circleRadius
  topAndBottomLine = hrule topAndBottomLineWidth # lc (regionPerimC colorScheme) # lwG defaultLineWidth # alignL
  finalDia = topAndBottomLine <> alignB (topAndBottomLine <> (middle # alignT))
