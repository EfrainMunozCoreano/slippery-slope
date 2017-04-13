module Remote exposing (..)

import Json.Decode as Decode exposing (Decoder)
import Dict exposing (Dict)
import GeoJson exposing (GeoJson)
import Html
import Http
import RemoteData exposing (WebData, RemoteData(..))
import Shared
import SlippyMap.Geo.Tile as Tile exposing (Tile)
import SlippyMap.Geo.Transform as Transform exposing (Transform)
import SlippyMap.LowLevel as LowLevel
import SlippyMap.StaticGeoJSon as StaticGeoJSon
import Svg exposing (Svg)


type alias Model =
    { transform : Transform
    , tiles : Dict Tile.Comparable (WebData GeoJson)
    }


type Msg
    = GeoJsonTileResponse Tile.Comparable (WebData GeoJson)


init : ( Model, Cmd Msg )
init =
    let
        transform =
            Shared.transform

        scale =
            Transform.zoomScale
                (toFloat (floor transform.zoom) - transform.zoom)

        centerPoint =
            Transform.locationToPixelPoint transform transform.center
                |> (\{ x, y } -> { x = toFloat x, y = toFloat y })

        topLeftCoordinate =
            Transform.pixelPointToCoordinate transform
                ({ x = centerPoint.x - transform.width / 2
                 , y = centerPoint.y - transform.height / 2
                 }
                    |> (\{ x, y } -> { x = floor x, y = floor y })
                )

        bottomRightCoordinate =
            Transform.pixelPointToCoordinate transform
                ({ x = centerPoint.x + transform.width / 2
                 , y = centerPoint.y + transform.height / 2
                 }
                    |> (\{ x, y } -> { x = floor x, y = floor y })
                )

        bounds =
            { topLeft = topLeftCoordinate
            , topRight =
                { topLeftCoordinate | column = bottomRightCoordinate.column }
            , bottomRight = bottomRightCoordinate
            , bottomLeft =
                { topLeftCoordinate | row = bottomRightCoordinate.row }
            }

        tilesToLoad =
            Tile.cover bounds
    in
        { transform = transform
        , tiles = Dict.empty
        }
            ! (List.map getGeoJsonTile tilesToLoad)


view : Model -> Svg Msg
view model =
    LowLevel.container model.transform
        [ StaticGeoJSon.tileLayer (tileToGeoJson model) model.transform
        ]


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GeoJsonTileResponse key data ->
            { model | tiles = Dict.insert key data model.tiles } ! []


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.none


main : Program Never Model Msg
main =
    Html.program
        { init = init
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


getGeoJsonTile : Tile -> Cmd Msg
getGeoJsonTile ({ z, x, y } as tile) =
    let
        comparable =
            Tile.toComparable tile

        url =
            ("https://tile.mapzen.com/mapzen/vector/v1/earth/"
                ++ toString z
                ++ "/"
                ++ toString (x % (2 ^ z))
                ++ "/"
                ++ toString (y % (2 ^ z))
                ++ ".json"
                ++ "?api_key=mapzen-A4166oq"
            )
    in
        Http.get url GeoJson.decoder
            |> RemoteData.sendRequest
            |> Cmd.map (GeoJsonTileResponse comparable)


vectorTileDecoder : Decoder (List ( String, GeoJson ))
vectorTileDecoder =
    Decode.keyValuePairs GeoJson.decoder


tileToGeoJson : Model -> Tile -> GeoJson
tileToGeoJson model tile =
    let
        comparable =
            Tile.toComparable tile

        tileGeoJson =
            Dict.get comparable model.tiles
                |> Maybe.withDefault RemoteData.NotAsked
                |> RemoteData.toMaybe
                |> Maybe.withDefault
                    ( GeoJson.FeatureCollection [], Nothing )
    in
        tileGeoJson
