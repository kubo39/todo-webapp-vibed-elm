module Main exposing (..)

import Browser
import Html exposing (Html, button, div, header, h1, input, li, section, text, ul)
import Html.Attributes exposing (placeholder)
import Html.Events exposing (onClick)
import Http
import Json.Decode exposing (..)
import Json.Encode exposing (Value)
import Html.Attributes exposing (type_)

-- MAIN

main : Program () Model Msg
main =
  Browser.document
    { init = init
    , update = update
    , view = \model -> { title = "Todo App", body = [view model] }
    , subscriptions = \_ -> Sub.none
    }

-- MODEL

type alias Model =
  { tasks : List Task
  , status : Status
  , field : String
  , checked : Bool
  , errorMsg : String
  }

type Status
  = Failure
  | Loading
  | Success

init : () -> (Model, Cmd Msg)
init _ =
  ({
    tasks = []
  , status = Loading
  , field = ""
  , checked = False
  , errorMsg = ""
  }
  , getTasks
  )

-- UPDATE

type Msg
  = GotTasks (Result Http.Error (List Task))
  | PostNewTask
  | UpdateField String
  | Check Int Bool
  | Delete Int

type alias Task =
  { id : Int
  , text : String
  , completed : Bool
  , created_at : String
  }

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    GotTasks result ->
      case result of
        Ok tasks ->
          ({ model
               | status = Success
                , tasks = tasks
               , field = ""
               , errorMsg = ""
           }, Cmd.none)
        Err _ ->
          ({ model
               | status = Failure
               , field = ""
               , errorMsg = "Failed to load tasks"
           }, Cmd.none)

    PostNewTask ->
      ({model
        | status = Loading
        , field = ""
        , errorMsg = ""
      }, postTask model.field)

    UpdateField newField ->
      ({ model
          | field = newField
          , errorMsg = ""
        }
      , Cmd.none
      )

    Check id completed ->
      ({ model
          | errorMsg = ""
       }
      , updateTask id completed
      )

    Delete id ->
      ({ model
          | errorMsg = ""
       }
      , deleteTask id
      )

-- VIEW

view : Model -> Html Msg
view model =
  case model.status of
    Failure ->
      div []
        [ text model.errorMsg ]

    Loading ->
      div [] [ text "Loading" ]

    Success ->
      div []
        [ header
            []
            [ h1 []
              [ text "Todo App" ]
            ]
          , section []
            [ viewInputTask model
            , viewTasks model.tasks
            ]
        ]

viewTask : Task -> Html Msg
viewTask task =
  div []
    [ text (String.fromInt task.id ++ ": " ++ task.text)
    , text (if task.completed then " (completed)" else "")
    , input
        [ type_ "checkbox"
        , Html.Attributes.checked task.completed
        , Html.Events.onClick (Check task.id (not task.completed))
        ]
        []
    , button
        [ type_ "button"
        , onClick (Delete task.id)
        ]
        [ text "Delete" ]
    , text (" (作成日: " ++ task.created_at ++ ") ")
    ]

viewTasks : List Task -> Html Msg
viewTasks tasks =
  ul []
    (List.map viewTask tasks
    |> List.map (\task -> li [] [ task ])
    )

viewInputTask : Model -> Html Msg
viewInputTask model =
  div []
    [ text "Add a new task"
    , input [
        type_ "text"
      , placeholder "Task"
      , Html.Attributes.value model.field
      , Html.Events.onInput UpdateField
      ]
      []
    , button
        [ type_ "button", onClick PostNewTask ]
        [ text "Add" ]
    ]

-- HTTP

getTasks : Cmd Msg
getTasks =
  Http.request
    { method = "GET"
    , headers = [
      Http.header "Content-Type" "application/json"
    ]
    , url = "http://127.0.0.1:8080/tasks"
    , body = Http.emptyBody
    , expect = Http.expectJson GotTasks tasksDecoder
    , timeout = Nothing
    , tracker = Nothing
    }

taskDecoder : Decoder Task
taskDecoder =
  Json.Decode.map4 Task
    (Json.Decode.field "id" Json.Decode.int)
    (Json.Decode.field "text" Json.Decode.string)
    (Json.Decode.field "completed" Json.Decode.bool)
    (Json.Decode.field "createdAt" Json.Decode.string)

tasksDecoder : Decoder (List Task)
tasksDecoder =
  Json.Decode.list taskDecoder

postTask: String -> Cmd Msg
postTask text =
  Http.post
    { url = "http://127.0.0.1:8080/tasks"
    , body = Http.jsonBody (taskEncoder text)
    , expect = Http.expectJson GotTasks tasksDecoder
    }

updateTask : Int -> Bool -> Cmd Msg
updateTask id completed =
  Http.post
    { url = "http://127.0.0.1:8080/tasks/" ++ String.fromInt id
    , body = Http.jsonBody (taskEncoder2 completed)
    , expect = Http.expectJson GotTasks tasksDecoder
    }

deleteTask : Int -> Cmd Msg
deleteTask id =
  Http.request
    { method = "DELETE"
    , headers = [
      Http.header "Content-Type" "application/json"
    ]
    , url = "http://127.0.0.1:8080/tasks/" ++ String.fromInt id
    , body = Http.emptyBody
    , expect = Http.expectJson GotTasks tasksDecoder
    , timeout = Nothing
    , tracker = Nothing
    }

taskEncoder : String -> Value
taskEncoder text =
  Json.Encode.object
    [ ("text", Json.Encode.string text) ]

taskEncoder2 : Bool -> Value
taskEncoder2 completed =
  Json.Encode.object
    [ ("completed", Json.Encode.bool completed) ]
