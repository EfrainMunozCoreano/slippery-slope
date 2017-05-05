module SlippyMap.Layer.Heatmap
    exposing
        ( Config
        , defaultConfig
        , layer
        )

{-| A layer to display markers.
-}

import Color exposing (Color)
import Color.Gradient as Gradient exposing (Gradient, Palette)
import Color.Interpolate as Interpolate
import Dict exposing (Dict)
import SlippyMap.Layer.LowLevel as Layer exposing (Layer)
import SlippyMap.Geo.Location as Location exposing (Location)
import SlippyMap.Geo.Point as Point exposing (Point)
import SlippyMap.Geo.Transform as Transform exposing (Transform)
import Svg exposing (Svg)
import Svg.Attributes
import Svg.Lazy


-- CONFIG


{-| Configuration for the layer.

Note: Your Config should never be held in your model. It should only appear in view code.
-}
type Config data
    = Config
        { radius : data -> Float
        , palette : Palette
        }


defaultConfig : Config Float
defaultConfig =
    Config
        { radius = identity
        , palette = defaultPalette
        }


defaultPalette : Palette
defaultPalette =
    Gradient.linearGradientFromStops Interpolate.RGB
        [ ( 0.4, Color.rgb 0 0 255 )
        , ( 0.5, Color.rgb 0 255 255 )
        , ( 0.7, Color.rgb 0 255 0 )
        , ( 0.8, Color.rgb 255 255 0 )
        , ( 1, Color.rgb 255 0 0 )
        ]
        8



-- LAYER


layer : Config data -> List ( Location, data ) -> Layer msg
layer config dataLocations =
    Layer.withRender (Layer.withoutAttribution) (render config dataLocations)


render : Config data -> List ( Location, data ) -> Transform -> Svg msg
render (Config config) dataLocations transform =
    let
        centerPoint =
            Transform.centerPoint transform

        bounds =
            Transform.locationBounds transform

        dataLocationsFiltered =
            List.filter
                (\( location, _ ) ->
                    Location.isInsideBounds bounds location
                )
                dataLocations

        clusteredPoints =
            cluster (Config config)
                transform
                dataLocationsFiltered

        --dataLocations
    in
        Svg.g
            [ Svg.Attributes.transform
                (""
                    ++ "translate("
                    ++ toString (round (transform.width / 2 - centerPoint.x))
                    ++ " "
                    ++ toString (round (transform.height / 2 - centerPoint.y))
                    ++ ")"
                )
            ]
            [ gradientDefinition
            , heatmapFilter config.palette
            , Svg.g [ Svg.Attributes.filter "url(#heatmapFilter)" ]
                (List.map renderWeightedPoint clusteredPoints)
            ]


renderLocation : Config data -> Transform -> ( Location, data ) -> Svg msg
renderLocation (Config config) transform ( location, data ) =
    let
        { x, y } =
            Transform.locationToPoint transform location
    in
        Svg.circle
            [ Svg.Attributes.cx (toString x)
            , Svg.Attributes.cy (toString y)
            , Svg.Attributes.r (toString <| config.radius data)
            , Svg.Attributes.fill "url(#radialGradient)"
            ]
            []


renderWeightedPoint : ( Point, Float ) -> Svg msg
renderWeightedPoint ( { x, y }, weight ) =
    Svg.circle
        [ Svg.Attributes.cx (toString x)
        , Svg.Attributes.cy (toString y)
        , Svg.Attributes.r (toString <| weight)
        , Svg.Attributes.fill "url(#radialGradient)"
        ]
        []


cluster : Config data -> Transform -> List ( Location, data ) -> List ( Point, Float )
cluster (Config config) transform dataLocations =
    dataLocations
        |> List.map
            (\( location, data ) ->
                ( Transform.locationToPoint transform location
                , config.radius data
                )
            )
        |> clusterHelp Dict.empty
        |> gridToList


type alias Grid =
    Dict ( Int, Int ) ( Point, Float )


clusterHelp : Grid -> List ( Point, Float ) -> Grid
clusterHelp grid weightedPoints =
    case weightedPoints of
        ( { x, y } as point, weight ) :: rest ->
            let
                xCell =
                    floor (x / 30)

                yCell =
                    floor (y / 30)

                newGrid =
                    Dict.update ( xCell, yCell )
                        (\maybeWeightedPoint ->
                            case maybeWeightedPoint of
                                Just ( p, w ) ->
                                    Just
                                        ( { x = (p.x * w + x * weight) / (w + weight)
                                          , y = (p.y * w + y * weight) / (w + weight)
                                          }
                                        , min (weight + w) 50
                                        )

                                Nothing ->
                                    Just ( point, weight )
                        )
                        grid
            in
                clusterHelp newGrid rest

        [] ->
            grid


gridToList : Grid -> List ( Point, Float )
gridToList =
    Dict.values


heatmapFilter : Palette -> Svg msg
heatmapFilter palette =
    let
        componentTransferPalette =
            palette
                |> List.reverse
                |> List.map Color.toRgb
                |> List.map
                    (\{ red, green, blue } ->
                        { red = toFloat red / 256 |> clamp 0 1
                        , green = toFloat green / 256 |> clamp 0 1
                        , blue = toFloat blue / 256 |> clamp 0 1
                        }
                    )

        componentTransferTableValues color =
            componentTransferPalette
                |> List.map (color >> toString)
                |> String.join " "
    in
        Svg.filter
            [ Svg.Attributes.id "heatmapFilter"
            ]
            [ Svg.feGaussianBlur
                [ Svg.Attributes.in_ "SourceAlpha"
                , Svg.Attributes.stdDeviation "15"
                , Svg.Attributes.result "blur"
                ]
                []
            , Svg.feFlood
                [ Svg.Attributes.floodColor "white"
                , Svg.Attributes.floodOpacity "0.1"
                , Svg.Attributes.result "floodFill"

                --, Svg.Attributes.x "0"
                --, Svg.Attributes.y "0"
                --, Svg.Attributes.width "100%"
                --, Svg.Attributes.height "100%"
                ]
                []
            , Svg.feBlend
                [ Svg.Attributes.in_ "blur"
                , Svg.Attributes.in2 "floodFill"
                , Svg.Attributes.mode "multiply"
                , Svg.Attributes.result "toTransfer"
                ]
                []
            , Svg.feComponentTransfer [ Svg.Attributes.in_ "toTransfer" ]
                [ Svg.feFuncR
                    [ Svg.Attributes.type_ "table"
                    , Svg.Attributes.tableValues
                        (componentTransferTableValues .red)
                    ]
                    []
                , Svg.feFuncG
                    [ Svg.Attributes.type_ "table"
                    , Svg.Attributes.tableValues
                        (componentTransferTableValues .green)
                    ]
                    []
                , Svg.feFuncB
                    [ Svg.Attributes.type_ "table"
                    , Svg.Attributes.tableValues
                        (componentTransferTableValues .blue)
                    ]
                    []
                , Svg.feFuncA
                    [ Svg.Attributes.type_ "table"
                    , Svg.Attributes.tableValues "0 0 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1"
                    ]
                    []
                ]
            ]


gradientDefinition : Svg msg
gradientDefinition =
    Svg.defs []
        [ Svg.radialGradient
            [ Svg.Attributes.id "radialGradient" ]
            [ Svg.stop
                [ Svg.Attributes.offset "0%"
                , Svg.Attributes.stopColor "black"
                , Svg.Attributes.stopOpacity "0.6"
                ]
                []
            , Svg.stop
                [ Svg.Attributes.offset "100%"
                , Svg.Attributes.stopColor "black"
                , Svg.Attributes.stopOpacity "0"
                ]
                []
            ]
        ]
