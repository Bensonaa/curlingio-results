port module Results exposing (init)

import Browser
import Browser.Navigation as Navigation
import CustomSvg exposing (..)
import Element as El exposing (Element, column, el, row, text)
import Element.Background as Background
import Element.Border as Border
import Element.Events as Events
import Element.Font as Font
import Element.Input as Input exposing (button)
import Element.Region as Region
import Html exposing (Html)
import Http
import Json.Decode as Decode exposing (Decoder, bool, float, int, list, nullable, string)
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import List.Extra
import RemoteData exposing (RemoteData(..), WebData)
import RemoteData.Http
import Time
import Url
import Url.Parser exposing ((</>), Parser)



-- MODEL


gridSize : Int
gridSize =
    50


timeBetweenReloads : Int
timeBetweenReloads =
    10


type alias Model =
    { flags : Flags
    , hash : String
    , fullScreen : Bool
    , translations : WebData (List Translation)
    , items : WebData (List Item)
    , itemFilter : ItemFilter
    , product : WebData Product
    , event : WebData Event
    , scoringHilight : Maybe ScoringHilight
    , errorMsg : Maybe String
    , reloadIn : Int
    }


type Route
    = ItemsRoute
    | ProductRoute Int
    | EventRoute Int NestedEventRoute


type NestedEventRoute
    = DetailsRoute
    | RegistrationsRoute
    | DrawsRoute
    | DrawRoute Int
    | GameRoute String
    | StagesRoute
    | StageRoute Int
    | TeamsRoute
    | TeamRoute Int
    | ReportsRoute
    | ReportRoute String


type ScoringHilight
    = HilightHammers
    | HilightStolenEnds
    | HilightBlankEnds
    | Hilight1PointEnds
    | Hilight2PointEnds
    | Hilight3PointEnds
    | Hilight4PointEnds
    | Hilight5PlusPointEnds


type alias Translation =
    { key : String
    , label : String
    }


type alias Flags =
    { host : Maybe String
    , hash : Maybe String
    , lang : Maybe String
    , apiKey : Maybe String
    , subdomain : Maybe String
    , section : ItemsSection
    , registration : Bool
    , excludeEventSections : List String
    , defaultEventSection : Maybe String
    , eventId : Maybe Int
    , loggedInCurlerIds : List Int
    }


type ItemsSection
    = LeaguesSection
    | CompetitionsSection
    | ProductsSection


type alias ItemFilter =
    { page : Int
    , seasonDelta : Int
    , search : String
    , seasonSearchOpen : Bool
    }


type alias Item =
    { id : Int
    , name : String
    , summary : Maybe String
    , occursOn : Maybe String
    , location : Maybe String
    , noRegistrationMessage : Maybe String
    , price : Maybe String
    , addToCartUrl : Maybe String
    , addToCartText : Maybe String
    , publishResults : Bool
    }


type alias Product =
    { id : Int
    , name : String
    , summary : Maybe String
    , description : Maybe String
    , sponsor : Maybe Sponsor
    , addToCartUrl : Maybe String
    , addToCartText : Maybe String
    , totalWithTax : Maybe String
    , potentialDiscounts : List String
    }


type alias Event =
    { id : Int
    , name : String
    , summary : Maybe String
    , description : Maybe String
    , note : Maybe String
    , teamRestriction : String
    , ageRange : String
    , sponsor : Maybe Sponsor
    , startsOn : String
    , endsOn : String
    , state : EventState
    , noRegistrationMessage : Maybe String
    , registrationOpensAt : Maybe String
    , registrationClosesAt : Maybe String
    , addToCartUrl : Maybe String
    , addToCartText : Maybe String
    , totalWithTax : Maybe String
    , potentialDiscounts : List String
    , endScoresEnabled : Bool
    , shotByShotEnabled : Bool
    , numberOfEnds : Int
    , topRock : String
    , botRock : String
    , sheetNames : List String
    , teams : List Team
    , registrations : List Registration
    , stages : List Stage
    , draws : List Draw
    }


type EventState
    = EventStatePending
    | EventStateActive
    | EventStateComplete


type alias Sponsor =
    { logoUrl : String
    , name : Maybe String
    , url : Maybe String
    }


type alias Team =
    { id : Int
    , name : String
    , shortName : String
    , coach : Maybe String
    , affiliation : Maybe String
    , location : Maybe String
    , contactName : Maybe String
    , contactEmail : Maybe String
    , contactPhone : Maybe String
    , imageUrl : Maybe String
    , lineup : List TeamCurler
    }


type alias TeamCurler =
    { curlerId : Int
    , position : Maybe TeamPosition
    , skip : Bool
    , name : String
    , delivery : Maybe RockDelivery
    , clubName : Maybe String
    , clubCity : Maybe String
    , photoUrl : Maybe String
    }


type TeamPosition
    = TeamFourth
    | TeamThird
    | TeamSecond
    | TeamFirst
    | TeamAlternate


type RockDelivery
    = RockDeliveryRight
    | RockDeliveryLeft


type alias Registration =
    { curlerName : Maybe String
    , teamName : Maybe String
    , skipName : Maybe String
    , position : Maybe String
    , lineup : Maybe Lineup
    }


type alias Lineup =
    { first : Maybe String
    , second : Maybe String
    , third : Maybe String
    , fourth : Maybe String
    , alternate : Maybe String
    }


type alias Stage =
    { id : Int
    , parentId : Maybe Int
    , stageType : StageType
    , name : String
    , iterations : Int
    , rankingMethod : RankingMethod
    , pointsPerWin : Float
    , pointsPerTie : Float
    , pointsPerLoss : Float
    , pointsPerEnd : List Float
    , tiebreaker : Tiebreaker
    , groups : Maybe (List Group)
    , teamIds : List Int
    , games : List Game
    }


type StageType
    = RoundRobin
    | Bracket


type RankingMethod
    = PointsRanking
    | SkinsRanking
    | ScoresRanking


type Tiebreaker
    = TiebreakerNone
    | TiebreakerHeadToHead
    | TiebreakerHeadToHeadThenSkillRank
    | TiebreakerScores


type alias Draw =
    { id : Int
    , startsAt : String
    , label : String
    , attendance : Int
    , drawSheets : List (Maybe String)
    }


type alias Group =
    { id : Int
    , name : String
    }


type alias Game =
    { id : String
    , name : String
    , state : GameState
    , coords : Maybe GameCoords
    , sides : List Side
    }


type GameState
    = GamePending
    | GameActive
    | GameComplete


type alias GameCoords =
    { groupId : Int
    , row : Int
    , col : Int
    }


type alias Side =
    { teamId : Maybe Int
    , topRock : Bool
    , firstHammer : Bool
    , result : Maybe SideResult
    , score : Maybe Int
    , endScores : List Int
    , winnerId : Maybe String
    , loserId : Maybe String
    }


type SideResult
    = SideResultWon
    | SideResultLost
    | SideResultTied
    | SideResultConceded
    | SideResultForfeited
    | SideResultTimePenalized


type alias TeamResult =
    { team : Team
    , gamesPlayed : Int
    , wins : Int
    , losses : Int
    , ties : Int
    , points : Float
    }


type alias LineConnector =
    { fromCoords : ( Int, Int )
    , toCoords : ( Int, Int )
    }



-- DECODERS


decodeFlags : Decoder Flags
decodeFlags =
    let
        decodeSection : Decoder ItemsSection
        decodeSection =
            string
                |> Decode.andThen
                    (\str ->
                        case String.toLower str of
                            "competitions" ->
                                Decode.succeed CompetitionsSection

                            "products" ->
                                Decode.succeed ProductsSection

                            _ ->
                                Decode.succeed LeaguesSection
                    )
    in
    Decode.succeed Flags
        |> optional "host" (nullable string) Nothing
        |> optional "hash" (nullable string) Nothing
        |> optional "lang" (nullable string) Nothing
        |> optional "apiKey" (nullable string) Nothing
        |> optional "subdomain" (nullable string) Nothing
        |> optional "section" decodeSection LeaguesSection
        |> optional "registration" bool False
        |> optional "excludeEventSections" (list string) []
        |> optional "defaultEventSection" (nullable string) Nothing
        |> optional "eventId" (nullable int) Nothing
        |> optional "loggedInCurlerIds" (list int) []


decodeTranslations : Decoder (List Translation)
decodeTranslations =
    list decodeTranslation


decodeTranslation : Decoder Translation
decodeTranslation =
    Decode.succeed Translation
        |> required "key" string
        |> required "label" string


decodeItems : Decoder (List Item)
decodeItems =
    list decodeItem


decodeItem : Decoder Item
decodeItem =
    Decode.succeed Item
        |> required "id" int
        |> required "name" string
        |> optional "summary" (nullable string) Nothing
        |> optional "occurs_on" (nullable string) Nothing
        |> optional "location" (nullable string) Nothing
        |> optional "no_registration_message" (nullable string) Nothing
        |> optional "price" (nullable string) Nothing
        |> optional "add_to_cart_url" (nullable string) Nothing
        |> optional "add_to_cart_text" (nullable string) Nothing
        |> optional "publish_results" bool False


decodeSponsor : Decoder Sponsor
decodeSponsor =
    Decode.succeed Sponsor
        |> required "logo_url" string
        |> optional "name" (nullable string) Nothing
        |> optional "url" (nullable string) Nothing


decodeProduct : Decoder Product
decodeProduct =
    Decode.succeed Product
        |> required "id" int
        |> required "name" string
        |> optional "summary" (nullable string) Nothing
        |> optional "description" (nullable string) Nothing
        |> optional "sponsor" (nullable decodeSponsor) Nothing
        |> optional "add_to_cart_url" (nullable string) Nothing
        |> optional "add_to_cart_text" (nullable string) Nothing
        |> optional "total_with_tax" (nullable string) Nothing
        |> optional "potential_discounts" (list string) []


decodeEvent : Decoder Event
decodeEvent =
    let
        decodeEventState : Decoder EventState
        decodeEventState =
            string
                |> Decode.andThen
                    (\str ->
                        case String.toLower str of
                            "pending" ->
                                Decode.succeed EventStatePending

                            "active" ->
                                Decode.succeed EventStateActive

                            _ ->
                                Decode.succeed EventStateComplete
                    )
    in
    Decode.succeed Event
        |> required "id" int
        |> required "name" string
        |> optional "summary" (nullable string) Nothing
        |> optional "description" (nullable string) Nothing
        |> optional "note" (nullable string) Nothing
        |> required "team_restriction" string
        |> required "age_range" string
        |> optional "sponsor" (nullable decodeSponsor) Nothing
        |> required "starts_on" string
        |> required "ends_on" string
        |> optional "state" decodeEventState EventStateComplete
        |> optional "no_registration_message" (nullable string) Nothing
        |> optional "registration_opens_at" (nullable string) Nothing
        |> optional "registration_closes_at" (nullable string) Nothing
        |> optional "add_to_cart_url" (nullable string) Nothing
        |> optional "add_to_cart_text" (nullable string) Nothing
        |> optional "total_with_tax" (nullable string) Nothing
        |> optional "potential_discounts" (list string) []
        |> optional "end_scores_enabled" bool False
        |> optional "shot_by_shot_enabled" bool False
        |> optional "number_of_ends" int 10
        |> optional "top_rock" string "red"
        |> optional "bot_rock" string "yellow"
        |> optional "sheet_names" (list string) []
        |> optional "teams" (list decodeTeam) []
        |> optional "registrations" (list decodeRegistration) []
        |> optional "stages" (list decodeStage) []
        |> optional "draws" (list decodeDraw) []


decodeTeam : Decoder Team
decodeTeam =
    Decode.succeed Team
        |> required "id" int
        |> required "name" string
        |> required "short_name" string
        |> optional "coach" (nullable string) Nothing
        |> optional "affiliation" (nullable string) Nothing
        |> optional "location" (nullable string) Nothing
        |> optional "contact_name" (nullable string) Nothing
        |> optional "contact_email" (nullable string) Nothing
        |> optional "contact_phone" (nullable string) Nothing
        |> optional "image_url" (nullable string) Nothing
        |> optional "lineup" (list decodeTeamCurler) []


decodeTeamCurler : Decoder TeamCurler
decodeTeamCurler =
    let
        decodeTeamPosition : Decoder TeamPosition
        decodeTeamPosition =
            string
                |> Decode.andThen
                    (\str ->
                        case String.toLower str of
                            "fourth" ->
                                Decode.succeed TeamFourth

                            "third" ->
                                Decode.succeed TeamThird

                            "second" ->
                                Decode.succeed TeamSecond

                            "first" ->
                                Decode.succeed TeamFirst

                            _ ->
                                Decode.succeed TeamAlternate
                    )

        decodeDelivery : Decoder RockDelivery
        decodeDelivery =
            string
                |> Decode.andThen
                    (\str ->
                        case String.toLower str of
                            "left" ->
                                Decode.succeed RockDeliveryLeft

                            _ ->
                                Decode.succeed RockDeliveryRight
                    )
    in
    Decode.succeed TeamCurler
        |> required "curler_id" int
        |> optional "position" (nullable decodeTeamPosition) Nothing
        |> optional "skip" bool False
        |> required "name" string
        |> optional "delivery" (nullable decodeDelivery) Nothing
        |> optional "club_name" (nullable string) Nothing
        |> optional "club_city" (nullable string) Nothing
        |> optional "photo_url" (nullable string) Nothing


decodeRegistration : Decoder Registration
decodeRegistration =
    let
        decodeLineup : Decoder Lineup
        decodeLineup =
            Decode.succeed Lineup
                |> optional "first" (nullable string) Nothing
                |> optional "second" (nullable string) Nothing
                |> optional "third" (nullable string) Nothing
                |> optional "fourth" (nullable string) Nothing
                |> optional "alternate1" (nullable string) Nothing
    in
    Decode.succeed Registration
        |> optional "curler_name" (nullable string) Nothing
        |> optional "team_name" (nullable string) Nothing
        |> optional "skip_name" (nullable string) Nothing
        |> optional "position" (nullable string) Nothing
        |> optional "lineup" (nullable decodeLineup) Nothing


decodeStage : Decoder Stage
decodeStage =
    let
        decodeStageType : Decoder StageType
        decodeStageType =
            string
                |> Decode.andThen
                    (\str ->
                        case String.toLower str of
                            "bracket" ->
                                Decode.succeed Bracket

                            _ ->
                                Decode.succeed RoundRobin
                    )

        decodeRankingMethod : Decoder RankingMethod
        decodeRankingMethod =
            string
                |> Decode.andThen
                    (\str ->
                        case String.toLower str of
                            "skins" ->
                                Decode.succeed SkinsRanking

                            "scores" ->
                                Decode.succeed ScoresRanking

                            _ ->
                                Decode.succeed PointsRanking
                    )

        decodePointsPerEnd : Decoder (List Float)
        decodePointsPerEnd =
            string
                |> Decode.andThen
                    (\str ->
                        String.replace " " "" str
                            |> String.split ","
                            |> List.map (\s -> String.toFloat s)
                            |> List.filterMap identity
                            |> Decode.succeed
                    )

        decodeTiebreaker : Decoder Tiebreaker
        decodeTiebreaker =
            string
                |> Decode.andThen
                    (\str ->
                        case String.toLower str of
                            "head_to_head" ->
                                Decode.succeed TiebreakerHeadToHead

                            "head_to_head_then_skill_rank" ->
                                Decode.succeed TiebreakerHeadToHeadThenSkillRank

                            "scores" ->
                                Decode.succeed TiebreakerScores

                            _ ->
                                Decode.succeed TiebreakerNone
                    )

        decodeGroup : Decoder Group
        decodeGroup =
            Decode.succeed Group
                |> required "id" int
                |> required "name" string
    in
    Decode.succeed Stage
        |> required "id" int
        |> optional "parent_id" (nullable int) Nothing
        |> required "type" decodeStageType
        |> required "name" string
        |> optional "iterations" int 1
        |> optional "ranking_method" decodeRankingMethod PointsRanking
        |> optional "points_per_win" float 0
        |> optional "points_per_tie" float 0
        |> optional "points_per_loss" float 0
        |> optional "points_per_end" decodePointsPerEnd []
        |> optional "tiebreaker" decodeTiebreaker TiebreakerNone
        |> optional "groups" (nullable (list decodeGroup)) Nothing
        |> optional "team_ids" (list int) []
        |> optional "games" (list decodeGame) []


decodeDraw : Decoder Draw
decodeDraw =
    Decode.succeed Draw
        |> required "id" int
        |> required "starts_at" string
        |> required "label" string
        |> optional "attendance" int 0
        |> required "draw_sheets" (list (nullable string))


decodeGame : Decoder Game
decodeGame =
    let
        decodeGameState : Decoder GameState
        decodeGameState =
            string
                |> Decode.andThen
                    (\str ->
                        case String.toLower str of
                            "active" ->
                                Decode.succeed GameActive

                            "complete" ->
                                Decode.succeed GameComplete

                            _ ->
                                Decode.succeed GamePending
                    )

        decodeGameCoords : Decoder GameCoords
        decodeGameCoords =
            Decode.succeed GameCoords
                |> required "group_id" int
                |> required "row" int
                |> required "col" int

        decodeSide : Decoder Side
        decodeSide =
            let
                decodeSideResult : Decoder (Maybe SideResult)
                decodeSideResult =
                    string
                        |> Decode.andThen
                            (\str ->
                                case str of
                                    "won" ->
                                        Decode.succeed (Just SideResultWon)

                                    "lost" ->
                                        Decode.succeed (Just SideResultLost)

                                    "tied" ->
                                        Decode.succeed (Just SideResultTied)

                                    "conceded" ->
                                        Decode.succeed (Just SideResultConceded)

                                    "forfeited" ->
                                        Decode.succeed (Just SideResultForfeited)

                                    "time_penalized" ->
                                        Decode.succeed (Just SideResultTimePenalized)

                                    _ ->
                                        Decode.succeed Nothing
                            )
            in
            Decode.succeed Side
                |> optional "team_id" (nullable int) Nothing
                |> optional "top_rock" bool False
                |> optional "first_hammer" bool False
                |> optional "result" decodeSideResult Nothing
                |> optional "score" (nullable int) Nothing
                |> optional "end_scores" (list int) []
                |> optional "winner_id" (nullable string) Nothing
                |> optional "loser_id" (nullable string) Nothing
    in
    Decode.succeed Game
        |> required "id" string
        |> required "name" string
        |> required "state" decodeGameState
        |> optional "coords" (nullable decodeGameCoords) Nothing
        |> required "game_positions" (list decodeSide)



-- HELPERS


matchRoute : Maybe String -> Parser (Route -> a) a
matchRoute defaultEventSection =
    Url.Parser.oneOf
        [ Url.Parser.map ItemsRoute Url.Parser.top
        , Url.Parser.map ProductRoute (Url.Parser.s "products" </> Url.Parser.int)
        , Url.Parser.map EventRoute (Url.Parser.s "events" </> Url.Parser.int </> matchNestedEventRoute defaultEventSection)
        ]


matchNestedEventRoute : Maybe String -> Parser (NestedEventRoute -> a) a
matchNestedEventRoute defaultEventSection =
    Url.Parser.oneOf
        -- [ Url.Parser.map
        --     (case defaultEventSection of
        --         Just "registrations" ->
        --             RegistrationsRoute
        --
        --         Just "draws" ->
        --             DrawsRoute
        --
        --         Just "stages" ->
        --             StagesRoute
        --
        --         Just "teams" ->
        --             TeamsRoute
        --
        --         Just "reports" ->
        --             ReportsRoute
        --
        --         _ ->
        --             DetailsRoute
        --     )
        --     Url.Parser.top
        [ Url.Parser.map DetailsRoute Url.Parser.top
        , Url.Parser.map DetailsRoute (Url.Parser.s "details")
        , Url.Parser.map RegistrationsRoute (Url.Parser.s "registrations")
        , Url.Parser.map DrawsRoute (Url.Parser.s "draws")
        , Url.Parser.map StagesRoute (Url.Parser.s "stages")
        , Url.Parser.map TeamsRoute (Url.Parser.s "teams")
        , Url.Parser.map ReportsRoute (Url.Parser.s "reports")
        , Url.Parser.map DrawRoute (Url.Parser.s "draws" </> Url.Parser.int)
        , Url.Parser.map GameRoute (Url.Parser.s "games" </> Url.Parser.string)
        , Url.Parser.map StageRoute (Url.Parser.s "stages" </> Url.Parser.int)
        , Url.Parser.map TeamRoute (Url.Parser.s "teams" </> Url.Parser.int)
        , Url.Parser.map ReportRoute (Url.Parser.s "reports" </> Url.Parser.string)
        ]


toRoute : Maybe String -> String -> Route
toRoute defaultEventSection hash =
    let
        url =
            let
                fixedHash =
                    hash
                        |> String.replace "#" ""
            in
            { host = "api.curling.io"
            , port_ = Nothing
            , protocol = Url.Https
            , query = Nothing
            , fragment = Nothing
            , path = fixedHash
            }

        parsed =
            Maybe.withDefault ItemsRoute (Url.Parser.parse (matchRoute defaultEventSection) url)
    in
    parsed


drawUrl : Int -> Draw -> String
drawUrl eventId draw =
    "/events/" ++ String.fromInt eventId ++ "/draws/" ++ String.fromInt draw.id


gameUrl : Int -> Game -> String
gameUrl eventId game =
    "/events/" ++ String.fromInt eventId ++ "/games/" ++ game.id


teamUrl : Int -> Team -> String
teamUrl eventId team =
    "/events/" ++ String.fromInt eventId ++ "/teams/" ++ String.fromInt team.id


stageUrl : Int -> Stage -> String
stageUrl eventId stage =
    let
        eventIdStr =
            String.fromInt eventId

        stageIdStr =
            String.fromInt stage.id
    in
    "/events/" ++ String.fromInt eventId ++ "/stages/" ++ String.fromInt stage.id


translate : List Translation -> String -> String
translate translations key =
    -- Translates the passed key to the current labels (server determines locale by url).
    case List.Extra.find (\translation -> String.toLower translation.key == String.toLower key) translations of
        Just translation ->
            translation.label

        Nothing ->
            key


colorNameToRGB : String -> String
colorNameToRGB color =
    case color of
        "red" ->
            "rgb(204, 0, 0)"

        "yellow" ->
            "rgb(204, 204, 0)"

        _ ->
            color


sideResultToString : List Translation -> Maybe SideResult -> String
sideResultToString translations result =
    translate translations
        (case result of
            Just SideResultWon ->
                "won"

            Just SideResultLost ->
                "lost"

            Just SideResultTied ->
                "tied"

            Just SideResultConceded ->
                "conceded"

            Just SideResultForfeited ->
                "forfeited"

            Just SideResultTimePenalized ->
                "was time penalized"

            Nothing ->
                "unknown"
        )


teamPositionToString : List Translation -> Maybe TeamPosition -> String
teamPositionToString translations position =
    translate translations
        (case position of
            Just TeamFourth ->
                "fourth"

            Just TeamThird ->
                "third"

            Just TeamSecond ->
                "second"

            Just TeamFirst ->
                "first"

            Just TeamAlternate ->
                "alternate"

            Nothing ->
                ""
        )


deliveryToString : List Translation -> Maybe RockDelivery -> String
deliveryToString translations delivery =
    case delivery of
        Just RockDeliveryRight ->
            translate translations "right"

        Just RockDeliveryLeft ->
            translate translations "left"

        Nothing ->
            "-"


init : Decode.Value -> ( Model, Cmd Msg )
init flags_ =
    case Decode.decodeValue decodeFlags flags_ of
        Ok flags ->
            let
                newHash =
                    let
                        eventRouteMaybe =
                            case flags.eventId of
                                Just eventId ->
                                    let
                                        section =
                                            case flags.defaultEventSection of
                                                Nothing ->
                                                    "details"

                                                Just "" ->
                                                    "details"

                                                Just defaultEventSection ->
                                                    defaultEventSection
                                    in
                                    "/events/" ++ String.fromInt eventId ++ "/" ++ section

                                Nothing ->
                                    ""
                    in
                    case flags.hash of
                        Just "" ->
                            eventRouteMaybe

                        Nothing ->
                            eventRouteMaybe

                        Just hash ->
                            hash

                newModel =
                    Model flags newHash False NotAsked NotAsked (ItemFilter 1 0 "" False) NotAsked NotAsked Nothing Nothing timeBetweenReloads
            in
            ( newModel
            , Cmd.batch
                [ getTranslations flags
                , Tuple.second (getItemsMaybe newModel newHash False)
                , Tuple.second (getEventMaybe newModel newHash False)
                , Tuple.second (getProductMaybe newModel newHash)
                ]
            )

        Err error ->
            let
                flags =
                    Flags Nothing Nothing Nothing Nothing Nothing LeaguesSection False [] Nothing Nothing []
            in
            ( Model flags "" False NotAsked NotAsked (ItemFilter 1 0 "" False) NotAsked NotAsked Nothing (Just (Decode.errorToString error)) 0
            , Cmd.none
            )


errorMessage : Http.Error -> String
errorMessage error =
    case error of
        Http.BadUrl string ->
            "Bad URL used: " ++ string

        Http.Timeout ->
            "Network timeout. Please check your internet connection."

        Http.NetworkError ->
            "Network error. Please check your internet connection."

        Http.BadStatus int ->
            "Bad status response from server. Please contact Curling I/O support if the issue persists for more than a few minutes."

        Http.BadBody string ->
            "Bad body response from server. Please contact Curling I/O support if the issue persists for more than a few minutes. Details: \"" ++ string ++ "\""


baseUrl : Flags -> String
baseUrl { host, lang } =
    let
        devUrl =
            -- Development
            "http://api.curling.test:3000/" ++ Maybe.withDefault "en" lang

        -- productionUrl =
        --     -- Production without caching
        --     "https://api.curling.io/" ++ Maybe.withDefault "en" lang
        --
        productionCachedUrl =
            -- Production cached via CDN (Fastly)
            "https://api-curlingio.global.ssl.fastly.net/" ++ Maybe.withDefault "en" lang
    in
    case host of
        Just h ->
            if String.contains "localhost" h || String.contains ".curling.test" h then
                devUrl
                --
                -- else if String.contains ".curling.io" h then
                --     productionUrl

            else
                productionCachedUrl

        Nothing ->
            productionCachedUrl


clubId : Flags -> String
clubId { apiKey, subdomain } =
    case ( apiKey, subdomain ) of
        ( _, Just subdomain_ ) ->
            subdomain_

        ( Just apiKey_, _ ) ->
            apiKey_

        _ ->
            ""


baseClubUrl : Flags -> String
baseClubUrl flags =
    baseUrl flags ++ "/clubs/" ++ clubId flags ++ "/"


baseClubSubdomainUrl : Flags -> String
baseClubSubdomainUrl flags =
    let
        devUrl =
            -- Development
            "http://" ++ clubId flags ++ ".curling.test:3000/" ++ Maybe.withDefault "en" flags.lang

        productionUrl =
            "https://" ++ clubId flags ++ ".curling.io/" ++ Maybe.withDefault "en" flags.lang
    in
    case flags.host of
        Just h ->
            if String.contains "localhost" h || String.contains ".curling.test" h then
                devUrl

            else
                productionUrl

        Nothing ->
            productionUrl


getItemsMaybe : Model -> String -> Bool -> ( WebData (List Item), Cmd Msg )
getItemsMaybe { flags, itemFilter, items } hash reload =
    case toRoute flags.defaultEventSection hash of
        ItemsRoute ->
            case ( items, reload ) of
                ( Success _, False ) ->
                    -- Already have the items.
                    ( items, Cmd.none )

                _ ->
                    -- On items route and haven't loaded them yet.
                    ( Loading, getItems flags itemFilter )

        _ ->
            -- Not on items route.
            ( items, Cmd.none )


getEventMaybe : Model -> String -> Bool -> ( WebData Event, Cmd Msg )
getEventMaybe { flags, event } hash reload =
    case toRoute flags.defaultEventSection hash of
        EventRoute eventId _ ->
            if reload then
                ( Loading, getEvent flags eventId )

            else
                case event of
                    Success event_ ->
                        if event_.id /= eventId then
                            -- Different event selected, load it.
                            ( Loading, getEvent flags eventId )

                        else
                            -- Already have the event.
                            ( event, Cmd.none )

                    _ ->
                        -- Haven't loaded an event yet.
                        ( Loading, getEvent flags eventId )

        _ ->
            -- Not on event route.
            ( event, Cmd.none )


getProductMaybe : Model -> String -> ( WebData Product, Cmd Msg )
getProductMaybe { flags, product } hash =
    case toRoute flags.defaultEventSection hash of
        ProductRoute productId ->
            case product of
                Success product_ ->
                    if product_.id /= productId then
                        -- Different product selected, load it.
                        ( Loading, getProduct flags productId )

                    else
                        -- Already have the product.
                        ( product, Cmd.none )

                _ ->
                    -- Haven't loaded a product yet.
                    ( Loading, getProduct flags productId )

        _ ->
            -- Not o product route.
            ( product, Cmd.none )


getTranslations : Flags -> Cmd Msg
getTranslations flags =
    let
        url =
            baseUrl flags ++ "/translations"
    in
    RemoteData.Http.get url GotTranslations decodeTranslations


itemsSectionName : ItemsSection -> String
itemsSectionName section =
    case section of
        LeaguesSection ->
            "leagues"

        CompetitionsSection ->
            "competitions"

        ProductsSection ->
            "products"


getItems : Flags -> ItemFilter -> Cmd Msg
getItems flags itemFilter =
    let
        params =
            case ( itemFilter.page, itemFilter.seasonDelta ) of
                ( 0, 0 ) ->
                    ""

                ( 0, seasonDelta ) ->
                    "?occurred=" ++ String.fromInt seasonDelta

                ( page, 0 ) ->
                    "?page=" ++ String.fromInt page

                ( page, seasonDelta ) ->
                    "?page=" ++ String.fromInt page ++ "&occurred=" ++ String.fromInt seasonDelta

        url =
            baseClubUrl flags
                ++ itemsSectionName flags.section
                ++ params
    in
    RemoteData.Http.get url GotItems decodeItems


getEvent : Flags -> Int -> Cmd Msg
getEvent flags id =
    let
        url =
            baseClubUrl flags
                ++ "events/"
                ++ String.fromInt id
    in
    RemoteData.Http.get url GotEvent decodeEvent


getProduct : Flags -> Int -> Cmd Msg
getProduct flags id =
    let
        url =
            baseClubUrl flags
                ++ "products/"
                ++ String.fromInt id
    in
    RemoteData.Http.get url GotProduct decodeProduct


eventSections : List String -> Event -> List String
eventSections excludeEventSections event =
    let
        -- Check if a section is included (not in the explicitly excluded sections list).
        included section =
            List.map String.toLower excludeEventSections
                |> List.member (String.toLower section)
                |> not

        hasData section =
            let
                hasRegistrations =
                    not (List.isEmpty event.registrations)

                hasDraws =
                    not (List.isEmpty event.draws)

                hasStages =
                    not (List.isEmpty event.stages)

                hasTeams =
                    not (List.isEmpty event.teams)

                hasCompletedGames =
                    List.any (\g -> g.state == GameComplete) (gamesFromStages event.stages)

                hasEndScores =
                    event.endScoresEnabled
            in
            case section of
                "registrations" ->
                    hasRegistrations

                "draws" ->
                    hasDraws

                "stages" ->
                    hasStages

                "teams" ->
                    hasTeams

                "reports" ->
                    (hasDraws && hasTeams)
                        || hasCompletedGames

                _ ->
                    True
    in
    [ "details", "registrations", "draws", "stages", "teams", "reports" ]
        |> List.filter included
        |> List.filter hasData


eventSectionForRoute : NestedEventRoute -> String
eventSectionForRoute route =
    case route of
        DetailsRoute ->
            "details"

        RegistrationsRoute ->
            "registrations"

        DrawsRoute ->
            "draws"

        DrawRoute _ ->
            "draws"

        StagesRoute ->
            "stages"

        StageRoute _ ->
            "stages"

        GameRoute _ ->
            "draws"

        TeamsRoute ->
            "teams"

        TeamRoute _ ->
            "teams"

        ReportsRoute ->
            "reports"

        ReportRoute _ ->
            "reports"


gamesForTeam : List Game -> Team -> List Game
gamesForTeam games team =
    let
        participatedIn sides =
            List.any (\s -> s.teamId == Just team.id) sides
    in
    List.filter (\g -> participatedIn g.sides) games


teamsWithGames : List Team -> List Game -> List Team
teamsWithGames teams games =
    let
        teamHasGames team =
            not (List.isEmpty (gamesForTeam games team))
    in
    List.filter teamHasGames teams


teamResultsFor : Stage -> List Stage -> List Team -> List Game -> List TeamResult
teamResultsFor onStage allStages allTeams allGames =
    let
        includedStages =
            List.filter (\stage -> stage.id == onStage.id || stage.parentId == Just onStage.id) allStages

        sidesByTeamAndStage team stage =
            List.filter (\g -> g.state == GameComplete) stage.games
                |> List.map .sides
                |> List.concat
                |> List.filter (\side -> side.teamId == Just team.id)

        resultsByTeamAndStage team stage =
            sidesByTeamAndStage team stage
                |> List.map (\side -> side.result)
                |> List.filterMap identity

        winsByTeamAndStage team stage =
            resultsByTeamAndStage team stage
                |> List.filter (\result -> result == SideResultWon)
                |> List.length

        lossesByTeamAndStage team stage =
            let
                isLoss result =
                    (result == SideResultLost)
                        || (result == SideResultConceded)
                        || (result == SideResultForfeited)
                        || (result == SideResultTimePenalized)
            in
            resultsByTeamAndStage team stage
                |> List.filter isLoss
                |> List.length

        tiesByTeamAndStage team stage =
            resultsByTeamAndStage team stage
                |> List.filter (\result -> result == SideResultTied)
                |> List.length

        pointsByTeamAndStage team stage =
            case stage.rankingMethod of
                PointsRanking ->
                    (toFloat (winsByTeamAndStage team stage) * stage.pointsPerWin)
                        + (toFloat (tiesByTeamAndStage team stage) * stage.pointsPerTie)
                        + (toFloat (lossesByTeamAndStage team stage) * stage.pointsPerLoss)

                SkinsRanking ->
                    let
                        pointsPerEnd index score =
                            if score > 0 then
                                List.Extra.getAt index stage.pointsPerEnd
                                    |> Maybe.withDefault 0.0

                            else
                                0.0
                    in
                    List.map (\side -> side.endScores) (sidesByTeamAndStage team stage)
                        |> List.map (\endScores -> List.indexedMap pointsPerEnd endScores)
                        |> List.concat
                        |> List.sum

                ScoresRanking ->
                    List.map (\side -> side.score) (sidesByTeamAndStage team stage)
                        |> List.filterMap identity
                        |> List.sum
                        |> toFloat

        gamesPlayed team =
            let
                gamesPlayedByStage stage =
                    List.length (sidesByTeamAndStage team stage)
            in
            List.map gamesPlayedByStage includedStages
                |> List.sum

        wins team =
            List.map (winsByTeamAndStage team) includedStages
                |> List.sum

        losses team =
            List.map (lossesByTeamAndStage team) includedStages
                |> List.sum

        ties team =
            List.map (tiesByTeamAndStage team) includedStages
                |> List.sum

        points team =
            List.map (pointsByTeamAndStage team) includedStages
                |> List.sum
    in
    List.map (\id -> List.Extra.find (\team -> team.id == id) allTeams) onStage.teamIds
        |> List.filterMap identity
        |> List.map (\team -> TeamResult team (gamesPlayed team) (wins team) (losses team) (ties team) (points team))


teamResultsRankedByPoints : List TeamResult -> List TeamResult
teamResultsRankedByPoints teamResults =
    List.sortBy .points teamResults
        |> List.reverse


teamHasDetails : Team -> Bool
teamHasDetails team =
    -- Check if there are any team details to show.
    not (List.isEmpty team.lineup)
        || (team.contactName /= Nothing)
        || (team.contactEmail /= Nothing)
        || (team.contactPhone /= Nothing)


findTeamForSide : List Team -> Side -> Maybe Team
findTeamForSide teams side =
    List.Extra.find (\t -> Just t.id == side.teamId) teams


sheetNameForGame : Event -> Maybe Game -> String
sheetNameForGame event game =
    let
        drawHasGame : Game -> Draw -> Bool
        drawHasGame game_ draw =
            List.any (\gameId -> gameId == Just game_.id) draw.drawSheets

        sheetNumber : Game -> Draw -> Maybe Int
        sheetNumber game_ draw =
            let
                matching gameId =
                    gameId == Just game_.id
            in
            List.Extra.findIndex matching draw.drawSheets
    in
    case game of
        Just game_ ->
            case List.Extra.find (drawHasGame game_) event.draws of
                Just draw ->
                    case sheetNumber game_ draw of
                        Just index ->
                            List.Extra.getAt index event.sheetNames
                                |> Maybe.withDefault ""

                        Nothing ->
                            ""

                Nothing ->
                    ""

        Nothing ->
            ""


gameScore : Game -> Maybe ( Int, Int ) -> Maybe String
gameScore game orderByTeamIds =
    let
        sides =
            -- If we passed team ids to order by, use them. Otherwise just use the default side positions.
            case orderByTeamIds of
                Just teamIds ->
                    [ List.Extra.find (\side -> side.teamId == Just (Tuple.first teamIds)) game.sides
                    , List.Extra.find (\side -> side.teamId == Just (Tuple.second teamIds)) game.sides
                    ]
                        |> List.filterMap identity

                Nothing ->
                    game.sides

        intScores =
            List.map (\s -> s.score) sides
                |> List.filterMap identity

        strScores =
            List.map String.fromInt intScores

        fromScores =
            case game.state of
                GameComplete ->
                    if Maybe.withDefault 0 (List.head intScores) > Maybe.withDefault 0 (List.Extra.getAt 1 intScores) then
                        String.join " > " strScores

                    else if Maybe.withDefault 0 (List.head intScores) < Maybe.withDefault 0 (List.Extra.getAt 1 intScores) then
                        String.join " < " strScores

                    else
                        String.join " = " strScores

                _ ->
                    ""
    in
    case fromScores of
        "" ->
            Nothing

        score ->
            Just score


stolenEnds : Bool -> List Game -> Team -> List Int
stolenEnds for games team =
    -- The for is a bool to indicate for (True) or against (False)
    let
        -- We need to look at each end score, and whether or not they had the hammer.
        stolenEndsForGame game =
            let
                -- We don't know if the team side is the first or second, so build a tuple so we know.
                sides =
                    if for then
                        ( List.Extra.find (\s -> s.teamId == Just team.id) game.sides
                        , List.Extra.find (\s -> s.teamId /= Just team.id) game.sides
                        )

                    else
                        ( List.Extra.find (\s -> s.teamId /= Just team.id) game.sides
                        , List.Extra.find (\s -> s.teamId == Just team.id) game.sides
                        )

                -- We don't care about the event's number of ends, just the max of either side.
                numberOfEnds =
                    List.map (\side -> List.length side.endScores) game.sides
                        |> List.maximum
                        |> Maybe.withDefault 0

                stolenEnd : Side -> Side -> Int -> Maybe Int
                stolenEnd sideFor sideAgainst endIndex =
                    let
                        hasHammer =
                            if endIndex > 0 then
                                -- Check if they lost the previous end (thus getting hammer for this end)
                                Maybe.withDefault 0 (List.Extra.getAt (endIndex - 1) sideAgainst.endScores) > 0

                            else
                                -- First end and first hammer?
                                sideFor.firstHammer == True
                    in
                    if hasHammer then
                        Nothing

                    else
                        List.Extra.getAt endIndex sideFor.endScores
            in
            case sides of
                ( Just sideFor, Just sideAgainst ) ->
                    List.range 0 numberOfEnds
                        |> List.map (stolenEnd sideFor sideAgainst)
                        |> List.filterMap identity
                        |> List.filter (\e -> e > 0)

                _ ->
                    []
    in
    List.map (\game -> stolenEndsForGame game) games
        |> List.concat


roundTwoDecimal : Float -> Float
roundTwoDecimal num =
    toFloat (round (num * 100)) / 100


gamesFromStages : List Stage -> List Game
gamesFromStages stages =
    List.map .games stages
        |> List.concat


findGameById : List Stage -> String -> Maybe Game
findGameById stages id =
    gamesFromStages stages
        |> List.Extra.find (\g -> g.id == id)


drawWithGameId : List Draw -> String -> Maybe Draw
drawWithGameId draws id =
    let
        hasGame draw =
            let
                matching gameId =
                    gameId == Just id
            in
            List.any matching draw.drawSheets
    in
    List.Extra.find hasGame draws



-- UPDATE


type Msg
    = NoOp
    | Tick Time.Posix
    | NavigateTo String
    | ToggleFullScreen
    | HashChanged Bool String
    | Reload
    | GotTranslations (WebData (List Translation))
    | GotItems (WebData (List Item))
    | IncrementPageBy Int
    | ToggleSeasonSearch
    | UpdateSearch String
    | UpdateSeasonDelta Int
    | AddToCart String
    | GotEvent (WebData Event)
    | GotProduct (WebData Product)
    | ToggleScoringHilight ScoringHilight


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        Tick _ ->
            let
                newReloadIn =
                    max 0 (model.reloadIn - 1)
            in
            ( { model | reloadIn = newReloadIn }, Cmd.none )

        NavigateTo newHash ->
            ( model, navigateTo newHash )

        ToggleFullScreen ->
            ( { model | fullScreen = not model.fullScreen }, Cmd.none )

        HashChanged reload hash ->
            let
                ( translations, translationsCmd ) =
                    case model.translations of
                        Success _ ->
                            ( model.translations, Cmd.none )

                        _ ->
                            ( Loading, getTranslations model.flags )

                ( items, itemsCmd ) =
                    getItemsMaybe model hash reload

                ( event, eventCmd ) =
                    getEventMaybe model hash reload

                ( product, productCmd ) =
                    getProductMaybe model hash
            in
            ( { model
                | hash = hash
                , translations = translations
                , items = items
                , product = product
                , event = event
              }
            , Cmd.batch
                [ translationsCmd
                , itemsCmd
                , productCmd
                , eventCmd
                ]
            )

        Reload ->
            update (HashChanged True model.hash) { model | reloadIn = timeBetweenReloads }

        GotTranslations response ->
            ( { model | translations = response, errorMsg = Nothing }, Cmd.none )

        GotItems response ->
            ( { model | items = response, errorMsg = Nothing }, Cmd.none )

        IncrementPageBy num ->
            let
                updatedItemFilter itemFilter =
                    { itemFilter | page = itemFilter.page + num }

                updatedModel =
                    { model | itemFilter = updatedItemFilter model.itemFilter }
            in
            ( updatedModel, getItems model.flags updatedModel.itemFilter )

        UpdateSearch val ->
            let
                updatedItemFilter itemFilter =
                    { itemFilter | search = String.toLower val }
            in
            ( { model | itemFilter = updatedItemFilter model.itemFilter }, Cmd.none )

        ToggleSeasonSearch ->
            let
                updatedItemFilter itemFilter =
                    { itemFilter | seasonSearchOpen = not itemFilter.seasonSearchOpen }
            in
            ( { model | itemFilter = updatedItemFilter model.itemFilter }, Cmd.none )

        UpdateSeasonDelta seasonDelta ->
            let
                updatedItemFilter itemFilter =
                    { itemFilter | seasonDelta = seasonDelta }

                updatedModel =
                    { model | itemFilter = updatedItemFilter model.itemFilter }
            in
            ( updatedModel, getItems model.flags updatedModel.itemFilter )

        AddToCart url ->
            ( model, Navigation.load url )

        GotEvent response ->
            ( { model | event = response, reloadIn = timeBetweenReloads }
            , Cmd.none
            )

        GotProduct response ->
            ( { model | product = response }
            , Cmd.none
            )

        ToggleScoringHilight scoringHilight ->
            ( { model
                | scoringHilight =
                    if model.scoringHilight == Just scoringHilight then
                        Nothing

                    else
                        Just scoringHilight
              }
            , Cmd.none
            )



-- COLORS


theme =
    { primary = El.rgb255 0 123 255
    , primaryFocused = El.rgb255 0 103 235
    , secondary = El.rgb255 108 117 125
    , secondaryFocused = El.rgb255 128 137 155
    , white = El.rgb255 255 255 255
    , grey = El.rgb255 222 226 230
    , greyLight = El.rgba 0 0 0 0.05
    , defaultText = El.rgb255 33 37 41
    }



-- VIEWS


viewButton textColor bgColor bgColorFocused content msg =
    button
        [ Background.color bgColor
        , Font.color textColor
        , El.paddingXY 12 10
        , Border.rounded 4
        , El.focused [ Background.color bgColorFocused ]
        ]
        { onPress = Just msg
        , label = text content
        }


viewButtonPrimary content msg =
    viewButton theme.white theme.primary theme.primaryFocused content msg


viewButtonSecondary content msg =
    viewButton theme.white theme.secondary theme.secondaryFocused content msg


view : Model -> Html Msg
view model =
    El.layout
        [ El.width El.fill
        , El.height El.fill
        , Font.size 16
        , Font.color theme.defaultText
        , Font.family
            [ Font.typeface "-apple-system"
            , Font.typeface "BlinkMacSystemFont"
            , Font.typeface "Segoe UI"
            , Font.typeface "Roboto"
            , Font.typeface "Helvetica Neue"
            , Font.typeface "Arial"
            , Font.typeface "Noto Sans"
            , Font.typeface "Noto Sans"
            , Font.typeface "Liberation Sans"
            , Font.typeface "Apple Color Emoji"
            , Font.typeface "Segoe UI Emoji"
            , Font.typeface "Segoe UI Symbol"
            , Font.typeface "Noto Color Emoji"
            , Font.sansSerif
            ]
        ]
    <|
        row
            [ El.width El.fill
            , El.inFront (el [ El.alignRight ] (viewReloadButton model))
            ]
            [ case model.errorMsg of
                Just errorMsg ->
                    viewNotReady model.fullScreen errorMsg

                Nothing ->
                    case model.translations of
                        Success translations ->
                            viewRoute model translations

                        Failure error ->
                            viewFetchError model (errorMessage error)

                        _ ->
                            viewNotReady model.fullScreen "Loading..."
            ]


viewRoute : Model -> List Translation -> Element Msg
viewRoute model translations =
    let
        viewLoading =
            viewNotReady model.fullScreen "Loading..."
    in
    case toRoute model.flags.defaultEventSection model.hash of
        ItemsRoute ->
            case model.items of
                Success items ->
                    viewItems model translations items

                Failure error ->
                    viewFetchError model (errorMessage error)

                _ ->
                    viewLoading

        ProductRoute id ->
            case model.product of
                Success product ->
                    viewProduct model.fullScreen translations product

                Failure error ->
                    viewFetchError model (errorMessage error)

                _ ->
                    viewLoading

        EventRoute id nestedRoute ->
            case model.event of
                Success event ->
                    viewEvent model translations nestedRoute event

                Failure error ->
                    viewFetchError model (errorMessage error)

                _ ->
                    viewLoading


viewReloadButton : Model -> Element Msg
viewReloadButton { flags, hash, fullScreen, reloadIn, event } =
    case toRoute flags.defaultEventSection hash of
        EventRoute _ nestedRoute ->
            case event of
                Success event_ ->
                    let
                        reloadEnabled =
                            -- Only if the event is active, end scores are enabled, and we're on a route / screen that is meaningfull to reload.
                            (event_.state == EventStateActive)
                                && event_.endScoresEnabled
                                && not (List.member nestedRoute [ DetailsRoute, TeamsRoute, ReportsRoute ])
                    in
                    if reloadEnabled then
                        if reloadIn <= 0 then
                            button
                                [ El.paddingXY 8 4
                                , Border.rounded 3
                                , Font.size 14
                                , Font.color theme.primary
                                , El.focused [ Background.color theme.grey ]
                                ]
                                { onPress = Just Reload
                                , label = text "Reload"
                                }

                        else
                            el
                                [ El.paddingXY 8 4
                                , Font.size 14
                                , Font.color theme.secondary
                                ]
                                (text ("Reload in " ++ String.fromInt reloadIn ++ "s"))

                    else
                        El.none

                _ ->
                    El.none

        _ ->
            El.none


viewNotReady : Bool -> String -> Element Msg
viewNotReady fullScreen message =
    el [] (text message)


viewFetchError : Model -> String -> Element Msg
viewFetchError { fullScreen, hash } message =
    row
        []
        [ column [ El.spacing 10 ]
            [ el [] (text message)
            , viewButtonPrimary "Reload" Reload
            ]
        ]


viewItems : Model -> List Translation -> List Item -> Element Msg
viewItems { flags, fullScreen, itemFilter } translations items =
    let
        viewPaging =
            let
                viewPageButton content msg =
                    button
                        [ Font.size 14
                        , El.padding 8
                        , Border.rounded 3
                        , Font.color theme.white
                        , Background.color theme.primary
                        , El.focused [ Background.color theme.primaryFocused ]
                        ]
                        { onPress = Just msg
                        , label = text content
                        }
            in
            row []
                [ if List.length items >= 10 then
                    viewPageButton "Next >" (IncrementPageBy 1)

                  else
                    El.none
                , if itemFilter.page > 1 then
                    viewPageButton "< Previous" (IncrementPageBy -1)

                  else
                    El.none
                ]

        viewSeasonDropDown =
            let
                times =
                    [ ( 1, "next_season" )
                    , ( 0, "this_season" )
                    , ( -1, "Last_season" )
                    , ( -2, "two_seasons_ago" )
                    , ( -3, "three_seasons_ago" )
                    ]

                seasonOption ( delta, label ) =
                    el
                        [ El.width El.fill
                        , El.padding 10
                        , Events.onClick (UpdateSeasonDelta delta)
                        , if delta == itemFilter.seasonDelta then
                            Background.color theme.grey

                          else
                            Background.color theme.white
                        ]
                        (text (translate translations label))

                seasonOptions =
                    if itemFilter.seasonSearchOpen then
                        column
                            [ El.width El.fill
                            , Border.width 1
                            , Border.color theme.grey
                            , Background.color theme.white
                            ]
                            (List.map seasonOption times)

                    else
                        El.none

                seasonSelected =
                    List.filter (\time -> Tuple.first time == itemFilter.seasonDelta) times
                        |> List.map Tuple.second
                        |> List.head
                        |> Maybe.withDefault "this_season"
                        |> translate translations
            in
            row
                [ El.width (El.px 184)
                , El.padding 10
                , Border.width 1
                , Border.color theme.grey
                , El.pointer
                , Events.onClick ToggleSeasonSearch
                , El.below seasonOptions
                ]
                [ el [] (text seasonSelected)
                , el [ El.alignRight ]
                    (text
                        (if itemFilter.seasonSearchOpen then
                            "▼"

                         else
                            "►"
                        )
                    )
                ]

        filteredItems =
            case String.trim itemFilter.search of
                "" ->
                    items

                _ ->
                    let
                        matches item =
                            String.contains itemFilter.search (String.toLower item.name)
                                || (case item.location of
                                        Just location ->
                                            String.contains itemFilter.search (String.toLower location)

                                        Nothing ->
                                            False
                                   )
                    in
                    List.filter matches items
    in
    column [ El.spacing 10, El.width El.fill ]
        [ row [ El.spacing 20 ]
            [ Input.text [ El.width (El.px 200), El.padding 10 ]
                { placeholder = Just (Input.placeholder [] (text (translate translations "search")))
                , text = itemFilter.search
                , onChange = UpdateSearch
                , label = Input.labelHidden ""
                }
            , viewSeasonDropDown
            ]
        , if List.isEmpty filteredItems then
            el [ El.padding 10 ] (text "No results found.")

          else
            let
                viewItemName item =
                    let
                        newPath =
                            case flags.section of
                                ProductsSection ->
                                    "/products/" ++ String.fromInt item.id

                                _ ->
                                    "/events/" ++ String.fromInt item.id
                    in
                    column [ El.spacingXY 0 5, El.paddingXY 10 15, Border.color theme.grey, Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 } ]
                        [ el [ Font.color theme.primary, El.pointer, Events.onClick (NavigateTo newPath) ] (text item.name)
                        , el [ Font.size 13 ] (text (Maybe.withDefault "" item.summary))
                        ]

                viewItemCell content =
                    el [ El.paddingXY 10 24, Border.color theme.grey, Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 } ] content

                viewItemOccursOn item =
                    viewItemCell (el [ El.centerX ] (text (Maybe.withDefault "" item.occursOn)))

                viewItemPrice item =
                    if flags.registration then
                        viewItemCell (el [ El.alignRight ] (text (Maybe.withDefault "" item.price)))

                    else
                        El.none

                viewItemRegister item =
                    if flags.registration then
                        case item.noRegistrationMessage of
                            Just msg ->
                                case item.addToCartUrl of
                                    Just url ->
                                        viewItemCell (el [ Font.color theme.primary, El.alignRight ] (text msg))

                                    Nothing ->
                                        viewItemCell (text msg)

                            Nothing ->
                                case ( item.addToCartUrl, item.addToCartText ) of
                                    ( Just addToCartUrl, Just addToCartText ) ->
                                        el
                                            [ El.paddingXY 10 17, Border.color theme.grey, Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 } ]
                                            (button
                                                [ Background.color theme.primary
                                                , Font.color theme.white
                                                , Font.size 14
                                                , El.alignRight
                                                , El.padding 8
                                                , Border.rounded 3
                                                , El.focused [ Background.color theme.primaryFocused ]
                                                ]
                                                { onPress = Just (AddToCart addToCartUrl)
                                                , label = text addToCartText
                                                }
                                            )

                                    _ ->
                                        viewItemCell (text "")

                    else
                        El.none
            in
            row
                []
                [ El.table [ El.spacingXY 0 15 ]
                    { data = filteredItems
                    , columns =
                        [ { header = El.none
                          , width = El.fill
                          , view = viewItemName
                          }
                        , { header = El.none
                          , width = El.fill
                          , view = viewItemOccursOn
                          }
                        , { header = El.none
                          , width = El.fill
                          , view = viewItemPrice
                          }
                        , { header = El.none
                          , width = El.fill
                          , view = viewItemRegister
                          }
                        ]
                    }
                ]
        , viewPaging
        ]


viewNoDataForRoute : List Translation -> Element Msg
viewNoDataForRoute translations =
    el [] (text (translate translations "no_data_for_route"))


viewSponsor : Sponsor -> Element Msg
viewSponsor sponsor =
    column [ El.spacing 10, El.alignTop ]
        [ case sponsor.url of
            Just url ->
                el [ El.pointer, Events.onClick (NavigateTo url) ]
                    (El.image [] { src = sponsor.logoUrl, description = Maybe.withDefault "" sponsor.name })

            Nothing ->
                El.image [] { src = sponsor.logoUrl, description = Maybe.withDefault "" sponsor.name }
        , case sponsor.name of
            Just name ->
                el [ El.alignRight ] (text name)

            Nothing ->
                El.none
        ]


viewProduct : Bool -> List Translation -> Product -> Element Msg
viewProduct fullScreen translations product =
    row [ El.spacing 20 ]
        [ column [ El.spacing 20, El.width El.fill, El.alignTop ]
            [ el [ Font.size 28 ] (text product.name)
            , case ( product.description, product.summary ) of
                ( Just description, _ ) ->
                    El.paragraph [] [ text description ]

                ( _, Just summary ) ->
                    El.paragraph [] [ text summary ]

                ( Nothing, Nothing ) ->
                    El.none
            , case product.totalWithTax of
                Just totalWithTax ->
                    column [ El.spacing 8 ]
                        [ el [ Font.bold ] (text (translate translations "total_with_tax"))
                        , el [] (text totalWithTax)
                        ]

                _ ->
                    El.none
            , case ( product.addToCartUrl, product.addToCartText ) of
                ( Just addToCartUrl, Just addToCartText ) ->
                    El.paragraph []
                        [ viewButtonPrimary addToCartText (AddToCart addToCartUrl)
                        ]

                _ ->
                    El.none
            , if not (List.isEmpty product.potentialDiscounts) then
                column [ El.spacing 5 ]
                    [ el [ Font.bold ] (text (translate translations "potential_discounts"))
                    , column [] (List.map (\d -> el [] (text d)) product.potentialDiscounts)
                    ]

              else
                El.none
            ]
        , case product.sponsor of
            Just sponsor ->
                viewSponsor sponsor

            Nothing ->
                El.none
        ]


viewEvent : Model -> List Translation -> NestedEventRoute -> Event -> Element Msg
viewEvent { flags, scoringHilight, fullScreen } translations nestedRoute event =
    let
        viewNavItem eventSection =
            let
                isActiveRoute =
                    -- TODO: This needs a bit of work. I don't like the string pattern matching, would prefer patterning on toRoute result.
                    eventSection == eventSectionForRoute nestedRoute

                newPath =
                    "/events/" ++ String.fromInt event.id ++ "/" ++ eventSection
            in
            el []
                (if isActiveRoute then
                    button
                        [ El.paddingXY 16 12
                        , Border.rounded 4
                        , Background.color theme.primary
                        , Font.color theme.white
                        , El.focused [ Background.color theme.primary ]
                        ]
                        { onPress = Just NoOp
                        , label = text (translate translations eventSection)
                        }

                 else
                    button
                        [ El.paddingXY 16 12
                        , Font.color theme.primary
                        , Border.rounded 4
                        , El.focused [ Background.color theme.white ]
                        ]
                        { onPress = Just (NavigateTo newPath)
                        , label = text (translate translations eventSection)
                        }
                )
    in
    column [ El.width El.fill, El.spacing 20 ]
        [ el [ Font.size 28, Font.medium ] (text event.name)
        , row [ El.width El.fill ]
            (List.map viewNavItem (eventSections flags.excludeEventSections event)
                ++ (if flags.eventId == Nothing then
                        [ el [ El.alignRight ]
                            (button
                                [ El.padding 16
                                , Font.color theme.primary
                                , Border.rounded 4
                                , El.focused [ Background.color theme.white ]
                                ]
                                { onPress = Just (NavigateTo "/events")
                                , label = text (translate translations (itemsSectionName flags.section) ++ " »")
                                }
                            )
                        ]

                    else
                        []
                   )
            )
        , case nestedRoute of
            DetailsRoute ->
                viewDetails translations event

            RegistrationsRoute ->
                viewRegistrations translations event.registrations

            DrawsRoute ->
                viewDraws translations scoringHilight event

            DrawRoute drawId ->
                case List.Extra.find (\d -> d.id == drawId) event.draws of
                    Just draw ->
                        viewDraw translations scoringHilight event draw

                    Nothing ->
                        viewNoDataForRoute translations

            GameRoute gameId ->
                let
                    findDraw =
                        drawWithGameId event.draws gameId

                    findGame =
                        findGameById event.stages gameId
                in
                case ( findDraw, findGame ) of
                    ( Just draw, Just game ) ->
                        let
                            sheetLabel =
                                sheetNameForGame event (Just game)
                        in
                        viewGame translations scoringHilight event sheetLabel True draw game

                    _ ->
                        viewNoDataForRoute translations

            StagesRoute ->
                case List.head event.stages of
                    Just stage ->
                        viewStages translations event stage

                    Nothing ->
                        viewNoDataForRoute translations

            StageRoute id ->
                case List.Extra.find (\s -> s.id == id) event.stages of
                    Just stage ->
                        viewStages translations event stage

                    Nothing ->
                        viewNoDataForRoute translations

            TeamsRoute ->
                viewTeams translations event

            TeamRoute id ->
                case List.Extra.find (\t -> t.id == id) event.teams of
                    Just team ->
                        viewTeam translations flags event team

                    Nothing ->
                        viewNoDataForRoute translations

            ReportsRoute ->
                viewReports translations event

            ReportRoute report ->
                viewReport translations scoringHilight event report
        ]


viewDetails : List Translation -> Event -> Element Msg
viewDetails translations event =
    row [ El.spacing 20 ]
        [ column [ El.spacing 20, El.width El.fill, El.alignTop ]
            [ case ( event.description, event.summary ) of
                ( Just description, _ ) ->
                    El.paragraph [] [ text description ]

                ( _, Just summary ) ->
                    El.paragraph [] [ text summary ]

                ( Nothing, Nothing ) ->
                    El.none
            , case event.totalWithTax of
                Just totalWithTax ->
                    column [ El.spacing 8 ]
                        [ el [ Font.bold ] (text (translate translations "total_with_tax"))
                        , el [] (text totalWithTax)
                        ]

                _ ->
                    El.none
            , case ( event.addToCartUrl, event.addToCartText ) of
                ( Just addToCartUrl, Just addToCartText ) ->
                    El.paragraph [ El.paddingEach { top = 10, right = 0, bottom = 20, left = 0 } ]
                        [ viewButtonPrimary addToCartText (AddToCart addToCartUrl)
                        ]

                _ ->
                    El.none
            , row [ El.width El.fill ]
                [ column [ El.width El.fill, El.spacing 5 ]
                    [ el [ Font.bold ] (text (translate translations "starts_on"))
                    , el [] (text event.startsOn)
                    ]
                , column [ El.width El.fill, El.spacing 5 ]
                    [ el [ Font.bold ] (text (translate translations "ends_on"))
                    , el [] (text event.endsOn)
                    ]
                ]
            , row [ El.width El.fill ]
                [ column [ El.width El.fill, El.spacing 5 ]
                    [ el [ Font.bold ] (text (translate translations "registration_opens_at"))
                    , el [] (text (Maybe.withDefault "" event.registrationOpensAt))
                    ]
                , column [ El.width El.fill, El.spacing 5 ]
                    [ el [ Font.bold ] (text (translate translations "registration_closes_at"))
                    , el [] (text (Maybe.withDefault "" event.registrationClosesAt))
                    ]
                ]
            , row [ El.width El.fill ]
                [ column [ El.width El.fill, El.spacing 5 ]
                    [ el [ Font.bold ] (text (translate translations "team_restriction"))
                    , el [] (text event.teamRestriction)
                    ]
                , column [ El.width El.fill, El.spacing 5 ]
                    [ el [ Font.bold ] (text (translate translations "age_range"))
                    , el [] (text event.ageRange)
                    ]
                ]
            , if not (List.isEmpty event.potentialDiscounts) then
                column [ El.width El.fill, El.spacing 5 ]
                    [ el [ Font.bold ] (text (translate translations "potential_discounts"))
                    , column [ El.spacing 5, El.padding 5 ] (List.map (\d -> el [] (text ("• " ++ d))) event.potentialDiscounts)
                    ]

              else
                El.none
            ]
        , case event.sponsor of
            Just sponsor ->
                viewSponsor sponsor

            Nothing ->
                El.none
        ]


viewRegistrations : List Translation -> List Registration -> Element Msg
viewRegistrations translations registrations =
    let
        hasCurlers =
            List.any (\r -> r.curlerName /= Nothing) registrations

        hasTeamNames =
            List.any (\r -> r.teamName /= Nothing) registrations

        hasSkipNames =
            List.any (\r -> r.skipName /= Nothing) registrations

        hasPositions =
            List.any (\r -> r.position /= Nothing) registrations

        hasLineups =
            List.any (\r -> r.lineup /= Nothing) registrations

        tableHeader content =
            el [ Font.bold, Border.widthEach { bottom = 1, left = 0, right = 0, top = 0 }, Border.color theme.grey, El.padding 12 ] (text (translate translations content))

        tableCell i content =
            el
                [ El.padding 12
                , Background.color
                    (if modBy 2 i == 0 then
                        theme.greyLight

                     else
                        theme.white
                    )
                ]
                (text content)

        curlerColumn =
            if hasCurlers then
                Just
                    { header = tableHeader "curler"
                    , width = El.fill
                    , view = \i reg -> tableCell i (Maybe.withDefault "-" reg.curlerName)
                    }

            else
                Nothing

        teamColumn =
            if hasTeamNames then
                Just
                    { header = tableHeader "team"
                    , width = El.fill
                    , view = \i reg -> tableCell i (Maybe.withDefault "-" reg.teamName)
                    }

            else
                Nothing

        skipColumn =
            if hasSkipNames then
                Just
                    { header = tableHeader "skip"
                    , width = El.fill
                    , view = \i reg -> tableCell i (Maybe.withDefault "-" reg.skipName)
                    }

            else
                Nothing

        positionColumn =
            if hasPositions then
                Just
                    { header = tableHeader "position"
                    , width = El.fill
                    , view =
                        \i reg ->
                            tableCell i
                                (case reg.position of
                                    Just pos ->
                                        translate translations pos

                                    Nothing ->
                                        "-"
                                )
                    }

            else
                Nothing

        lineupColumn =
            if hasLineups then
                Just
                    { header = tableHeader "lineup"
                    , width = El.fill
                    , view =
                        \i reg ->
                            tableCell i
                                (case reg.lineup of
                                    Just lineup ->
                                        [ lineup.first
                                        , lineup.second
                                        , lineup.third
                                        , lineup.fourth
                                        , lineup.alternate
                                        ]
                                            |> List.filterMap identity
                                            |> String.join ", "

                                    Nothing ->
                                        "-"
                                )
                    }

            else
                Nothing

        tableColumns =
            List.filterMap identity [ curlerColumn, teamColumn, skipColumn, positionColumn, lineupColumn ]
    in
    el [ El.width El.fill ]
        (if List.isEmpty registrations then
            El.paragraph [] [ text (translate translations "no_registrations") ]

         else
            El.indexedTable []
                { data = registrations
                , columns = tableColumns
                }
        )


viewDraws : List Translation -> Maybe ScoringHilight -> Event -> Element Msg
viewDraws translations scoringHilight event =
    El.none


viewTeams : List Translation -> Event -> Element Msg
viewTeams translations event =
    El.none


viewStages : List Translation -> Event -> Stage -> Element Msg
viewStages translations event onStage =
    El.none



-- REPORTS


viewReports : List Translation -> Event -> Element Msg
viewReports translations event =
    El.none


viewDraw : List Translation -> Maybe ScoringHilight -> Event -> Draw -> Element Msg
viewDraw translations scoringHilight event draw =
    El.none


viewGame : List Translation -> Maybe ScoringHilight -> Event -> String -> Bool -> Draw -> Game -> Element Msg
viewGame translations scoringHilight event sheetLabel detailed draw game =
    El.none


viewTeam : List Translation -> Flags -> Event -> Team -> Element Msg
viewTeam translations flags event team =
    El.none


viewReportScoringAnalysis : List Translation -> Maybe ScoringHilight -> Event -> List Team -> Element Msg
viewReportScoringAnalysis translations scoringHilight event teams =
    El.none


viewTeamScoringAnalysis : Event -> Team -> Element Msg
viewTeamScoringAnalysis event team =
    El.none


viewReportScoringAnalysisByHammer : List Translation -> Event -> Element Msg
viewReportScoringAnalysisByHammer translations event =
    El.none


viewReportTeamRosters : List Translation -> List Team -> Element Msg
viewReportTeamRosters translations teams =
    El.none


viewReportCompetitionMatrix : List Translation -> Event -> Element Msg
viewReportCompetitionMatrix translations event =
    El.none


viewReportAttendance : List Translation -> List Draw -> Element Msg
viewReportAttendance translations draws =
    El.none


viewReport : List Translation -> Maybe ScoringHilight -> Event -> String -> Element Msg
viewReport translations scoringHilight event report =
    El.none



-- PORTS


port navigateTo : String -> Cmd msg


port hashChangeReceiver : (String -> msg) -> Sub msg



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ hashChangeReceiver (HashChanged False)
        , Time.every 1000 Tick
        ]



-- MAIN


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }
