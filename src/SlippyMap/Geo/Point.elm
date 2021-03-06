module SlippyMap.Geo.Point exposing (Point, Bounds, add, subtract, multiplyBy, divideBy, distance)

{-|
@docs Point, Bounds, add, subtract, multiplyBy, divideBy, distance
-}


{-| A point
-}
type alias Point =
    { x : Float
    , y : Float
    }


{-| Represents a rectangular area in pixel coordinates.
-}
type alias Bounds =
    { topLeft : Point
    , bottomRight : Point
    }


{-| -}
add : Point -> Point -> Point
add q p =
    { x = p.x + q.x
    , y = p.y + q.y
    }


{-| -}
subtract : Point -> Point -> Point
subtract q p =
    { x = p.x - q.x
    , y = p.y - q.y
    }


{-| Multiply a point's coordinates by a factor.

    >>> { x = 1, y = 2 }
    ... |> multiplyBy 2
    { x = 2, y = 4 }

-}
multiplyBy : Float -> Point -> Point
multiplyBy k p =
    { x = p.x * k
    , y = p.y * k
    }


{-| Divide a point's coordinates by a factor.

    >>> { x = 2, y = 4 }
    ... |> divideBy 2
    { x = 1, y = 2 }

-}
divideBy : Float -> Point -> Point
divideBy k p =
    { x = p.x / k
    , y = p.y / k
    }


{-| -}
distance : Point -> Point -> Float
distance q p =
    subtract q p
        |> (\{ x, y } -> x ^ 2 + y ^ 2)
        |> sqrt
