import gleam/dict
import gleam/int
import gleam/list
import mvu/types.{
  type Location, type Message, type Model, type Piece, ClientClickedPiece,
  FirstOf2, Green, Location, Model, Orange, Player1, Player2, Purple, Red,
  SecondOf2, ThirdOf3,
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
      #(Green(Player2, ThirdOf3), Location(1, 0, 2)),
      #(Purple(Player2, SecondOf2), Location(1, 0, 3)),
    ]
    |> list.sort(compare)
  Model(pieces: dict.from_list(ps))
}

pub fn update(model: Model, message: Message) -> Model {
  case message {
    ClientClickedPiece(p) -> {
      // Can't be clicked if not alread in the model
      let assert Ok(Location(x, y, z)) = model.pieces |> dict.get(p)
      let pieces = model.pieces |> dict.insert(p, Location(x + 1, y - 1, z + 2))
      Model(pieces:)
    }
  }
}
