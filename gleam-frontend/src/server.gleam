import gleam/int
import gleam/list
import gleam/result
import gleam/string
import lustre/effect.{type Effect}
import mvu/types.{
  type Location, type Message, type Piece, Location, Player1, Player2,
  ServerInitPieces, ServerMovePiece, ServerSayHello, ServerShowIndicators,
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
    Player1 -> 0
    Player2 -> 11
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
    "move " <> ps -> {
      use #(p, l) <- result.try(parse_piece_location(ps))
      Ok(ServerMovePiece(p, l))
    }
    "init " <> xs -> {
      let xs = string.split(xs, " ")
      case xs {
        [_, ..rest] ->
          rest
          |> list.try_map(parse_piece_location)
          |> result.map(ServerInitPieces)
        [] -> Error(Nil)
      }
    }
    "show-indicators " <> is -> {
      is
      |> string.split(" ")
      |> list.try_map(parse_location)
      |> result.map(ServerShowIndicators)
    }
    "show-indicators" -> {
      // No space after 'show-indicators', so list is empty
      Ok(ServerShowIndicators([]))
    }

    _ -> Error(Nil)
  }
  |> result.replace_error("Invalid message:" <> msg)
}

fn parse_piece_location(text: String) -> Result(#(Piece, Location), Nil) {
  case text |> string.split_once(",") {
    Ok(#(p_str, l_str)) -> {
      use p <- result.try(parse_piece(p_str))
      use l <- result.try(parse_location(l_str))
      Ok(#(p, l))
    }
    Error(Nil) -> Error(Nil)
  }
}

fn parse_location(text: String) -> Result(Location, Nil) {
  case text |> string.split(",") |> list.try_map(int.parse) {
    Ok([x, y, z]) -> Ok(Location(x, y, z))
    _ -> Error(Nil)
  }
}

fn parse_piece(id: String) -> Result(Piece, Nil) {
  use id <- result.try(int.parse(id))
  use player <- result.try(case id {
    _ if 0 <= id && id <= 10 -> Ok(Player1)
    _ if 11 <= id && id <= 21 -> Ok(Player2)
    _ -> {
      echo "ID out of range: " <> int.to_string(id)
      Error(Nil)
    }
  })
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
  Ok(kind(player))
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
