module Interactive exposing (..)

import Html
import Json.Decode as Decode exposing (Decoder)
import Shared
import SlippyMap.Geo.Point as Point exposing (Point)
import SlippyMap.Geo.Transform as Transform exposing (Transform)
import SlippyMap.LowLevel as LowLevel
import SlippyMap.StaticImage as StaticImage
import Svg exposing (Svg)
import Svg.Attributes
import Svg.Events


type alias Model =
    Transform


type Msg
    = ZoomIn
    | ZoomOut
    | ZoomInAround Point
    | ZoomByAround Float Point


model : Model
model =
    Shared.transform


view : Model -> Svg Msg
view model =
    LowLevel.container model
        [ StaticImage.tileLayer model
        , Svg.rect
            [ Svg.Attributes.visibility "hidden"
            , Svg.Attributes.pointerEvents "all"
            , Svg.Attributes.width (toString model.width)
            , Svg.Attributes.height (toString model.height)
            , Svg.Events.on "dblclick"
                (Decode.map ZoomInAround clientPosition)
            , Svg.Events.on "wheel"
                (Decode.map2 ZoomByAround
                    (Decode.field "deltaY" Decode.float
                        |> Decode.map (\y -> -y / 100)
                    )
                    clientPosition
                )
            ]
            []
        , zoomControls
        ]


clientPosition : Decoder Point
clientPosition =
    Decode.map2 Point
        (Decode.field "offsetX" Decode.float)
        (Decode.field "offsetY" Decode.float)


zoomControls : Svg Msg
zoomControls =
    Svg.g [ Svg.Attributes.transform "translate(10, 10)" ]
        [ Svg.rect
            [ Svg.Attributes.width "24"
            , Svg.Attributes.height "48"
            , Svg.Attributes.rx "2"
            , Svg.Attributes.ry "2"
            , Svg.Attributes.fill "white"
            , Svg.Attributes.stroke "grey"
            ]
            []
        , Svg.text_
            [ Svg.Events.onClick ZoomIn
            , Svg.Attributes.x "12"
            , Svg.Attributes.y "16"
            , Svg.Attributes.textAnchor "middle"
            ]
            [ Svg.text "+" ]
        , Svg.text_
            [ Svg.Events.onClick ZoomOut
            , Svg.Attributes.x "12"
            , Svg.Attributes.y "36"
            , Svg.Attributes.textAnchor "middle"
            ]
            [ Svg.text "-" ]
        ]


update : Msg -> Model -> Model
update msg model =
    case msg of
        ZoomIn ->
            { model | zoom = model.zoom + 1 }

        ZoomOut ->
            { model | zoom = model.zoom - 1 }

        ZoomInAround point ->
            LowLevel.zoomToAround model (model.zoom + 1) point

        ZoomByAround delta point ->
            LowLevel.zoomToAround model (model.zoom + delta) point


main : Program Never Model Msg
main =
    Html.beginnerProgram
        { model = model
        , view = view
        , update = update
        }
