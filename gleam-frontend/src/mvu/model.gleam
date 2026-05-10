import gleam/dict
import gleam/int
import gleam/list
import gleam/option
import gleam/result
import mvu/types.{
  type Location, type Message, type Model, type Piece, Blue,
  ClientClickedIndicator, ClientClickedPiece, FirstOf2, Green, Location, Model,
  Orange, Player1, Player2, Purple, Red, SecondOf2, ThirdOf3,
}

fn compare(x: #(Piece, Location), y: #(Piece, Location)) {
  let #(_, l1) = x
  let #(_, l2) = y
  int.compare(l1.z, l2.z)
}

pub fn init(_args) {
  let ps =
    [
      #(Orange(Player1), Location(0, 0, 0)),
      #(Red(Player1, FirstOf2), Location(0, 1, 1)),
      #(Green(Player2, ThirdOf3), Location(1, 0, 1)),
      #(Purple(Player2, SecondOf2), Location(1, 0, 1)),
      #(Blue(Player1, ThirdOf3), Location(-1, 0, 0)),
    ]
    |> list.sort(compare)
  Model(pieces: dict.from_list(ps), indicators: option.None)
}

type Coordinate {
  Coordinate(x: Int, y: Int)
}

fn top_z(model: Model, coord: Coordinate) {
  let eq_coord = fn(c: Coordinate, l: Location) { c.x == l.x && c.y == l.y }
  let ls = model.pieces |> dict.values |> list.filter(eq_coord(coord, _))
  ls
  |> list.map(fn(l) { l.z })
  |> list.max(int.compare)
  |> result.unwrap(-1)
  |> int.add(1)
}

pub fn update(model: Model, message: Message) -> Model {
  case message {
    ClientClickedPiece(p) -> {
      // Can't be clicked if not alread in the model
      let assert Ok(Location(x, y, _)) = model.pieces |> dict.get(p)
      let loc = fn(x, y) { Location(x, y, top_z(model, Coordinate(x, y))) }
      let adjs = [
        loc(x + 1, y),
        loc(x, y + 1),
        loc(x - 1, y),
        loc(x, y - 1),
        loc(x + 1, y - 1),
        loc(x - 1, y + 1),
      ]
      let indicators = option.Some(#(p, adjs))
      Model(..model, indicators:)
    }
    ClientClickedIndicator(l) -> {
      let assert option.Some(#(p, is)) = model.indicators
      assert list.contains(is, l)
      let pieces =
        model.pieces
        |> dict.insert(p, l)
      Model(pieces:, indicators: option.None)
    }
    types.ClientClickedBackground -> Model(..model, indicators: option.None)
  }
}
