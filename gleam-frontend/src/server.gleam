import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lustre/effect.{type Effect}
import mvu/types.{
  type Message, type Piece, Location, ServerMovePiece, ServerSayHello,
  ServerShowIndicators,
}

/// Connect to websocket, use inside 'init'
pub fn connect(url: String) -> Effect(Message) {
  use dispatch <- effect.from
  use msg <- ffi_connect(url, fn() { ffi_send("connect new") })
  case parse_message(msg) {
    Ok(m) -> dispatch(m)
    Error(e) -> panic as { "Invalid server-message: " <> e }
  }
}

pub fn click_piece(piece: Piece) -> Effect(Message) {
  let id = piece_id(piece)
  send("click " <> id)
}

pub fn click_indicator(indicator_index: Int) -> Effect(Message) {
  send("click-indicator " <> indicator_index |> int.to_string)
}

fn piece_id(piece: Piece) -> String {
  let player_offset = case piece.player {
    types.Player1 -> 0
    types.Player2 -> 11
  }
  let piece_id = case piece {
    types.Blue1(_) -> 0
    types.Blue2(_) -> 1
    types.Blue3(_) -> 2
    types.Green1(_) -> 3
    types.Green2(_) -> 4
    types.Green3(_) -> 5
    types.Red1(_) -> 6
    types.Red2(_) -> 7
    types.Purple1(_) -> 8
    types.Purple2(_) -> 9
    types.Orange(_) -> 10
  }
  let id = player_offset + piece_id |> int.to_string
  id
}

/// Send function, to interact with JS ffi. Not exported on purpose - this module defines a function for each allowed message to send, ensuring no errors due to string-typos
fn send(msg: String) -> Effect(Message) {
  effect.from(fn(_dispatch) { ffi_send(msg) })
}

fn parse_message(msg: String) -> Result(Message, String) {
  case msg {
    "hello " <> _ -> Ok(ServerSayHello)
    "move " <> ps ->
      case string.split(ps, ",") |> list.try_map(int.parse) {
        Ok([i, x, y, z]) ->
          ServerMovePiece(
            piece: parse_piece(i),
            new_location: Location(x, y, z),
          )
          |> Ok
        _ -> Error(msg)
      }
    "init " <> _ -> {
      Ok(ServerSayHello)
    }
    "show-indicators " <> is -> {
      is
      |> string.split(" ")
      |> list.try_map(parse_location)
      |> result.map(ServerShowIndicators)
      |> result.replace_error(msg)
    }
    "show-indicators" -> {
      // No space after 'show-indicators', so list is empty
      Ok(ServerShowIndicators([]))
    }

    _ -> Error(msg)
  }
}

fn parse_location(text: String) -> Result(types.Location, String) {
  case text |> string.split(",") |> list.try_map(int.parse) {
    Ok([x, y, z]) -> Ok(Location(x, y, z))
    _ -> Error(text)
  }
}

fn parse_piece(id: Int) -> Piece {
  let player = case id {
    _ if 0 <= id && id <= 10 -> types.Player1
    _ if 11 <= id && id <= 21 -> types.Player2
    _ -> panic as { "ID out of range: " <> int.to_string(id) }
  }
  let kind = case id % 11 {
    0 -> types.Blue1
    1 -> types.Blue2
    2 -> types.Blue3
    3 -> types.Green1
    4 -> types.Green2
    5 -> types.Green3
    6 -> types.Red1
    7 -> types.Red2
    8 -> types.Purple1
    9 -> types.Purple2
    10 -> types.Orange
    _ -> panic as "Found new modulo 11 number, sheet"
  }
  kind(player)
}

// parse_location

@external(javascript, "./ffi.js", "connect")
fn ffi_connect(
  url: String,
  open_callback: fn() -> Nil,
  message_callback: fn(String) -> any,
) -> Nil

@external(javascript, "./ffi.js", "send")
fn ffi_send(msg: String) -> Nil
