import gameplay/component.{
  type Location, type Of2, type Of3, type Piece, type Player, Blue, FirstOf2,
  FirstOf3, Green, Location, Orange, Player1, Player2, Purple, Red, SecondOf2,
  SecondOf3, ThirdOf3,
}
import gleam/dict.{type Dict}
import gleam/list
import gleam/string
import lustre
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/element/keyed
import lustre/element/svg

pub fn main() {
  // let app = lustre.element(html.text("Hello, world!"))
  let app = lustre.simple(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}

pub type Model {
  Model(pieces: Dict(Piece, Location))
}

type Msg {
  ClientClickedPiece(piece: Piece)
}

fn piece(p: Piece, l: Location) -> Element(Msg) {
  // let player_key = case p.player {
  //   Player1 -> "1"
  //   Player2 -> "2"
  // }
  // let piece_key = case p {
  //   Orange(_) -> "o"
  //   Purple(..) -> "p"
  //   Green(..) -> "g"
  //   Red(..) -> "r"
  //   Blue(..) -> "b"
  // }
  component.piece(p, l, ClientClickedPiece)
}

fn init(_args) {
  Model(
    pieces: dict.from_list([
      #(Orange(Player1), Location(0, 0, 0)),
      #(Red(Player1, FirstOf2), Location(0, 1, 0)),
      #(Green(Player2, ThirdOf3), Location(1, 0, 0)),
      #(Purple(Player2, SecondOf2), Location(1, 0, 1)),
    ]),
  )
}

fn update(model: Model, msg: Msg) -> Model {
  let pieces = case msg {
    ClientClickedPiece(p) -> {
      // Can't be clicked if not alread in the model
      let assert Ok(Location(x, y, z)) = model.pieces |> dict.get(p)
      model.pieces |> dict.insert(p, Location(x + 1, y - 1, z))
    }
  }
  Model(pieces:)
}

fn view(model: Model) -> Element(Msg) {
  let head =
    h.head([], [
      h.link([a.rel("icon"), a.href("data:,")]),
      h.meta([
        a.name("viewport"),
        a.content("width=device-width, initial-scale=1"),
      ]),
      h.title([], "Hexa-game"),
      h.style([], ""),
    ])

  let w = window_width() /. 2.0
  let h = window_height() /. 2.0
  let ps =
    model.pieces
    |> dict.to_list
    |> list.map(fn(v) {
      let #(p, l) = v
      #(string.inspect(p), piece(p, l))
    })
  let board =
    svg.svg(
      [
        a.styles([
          #("background", "blanchedalmond"),
          #("display", "flex"),
          #("justify-conten", "center"),
          #("align-items", "center"),
          #("height", "100vh"),
          #("margin", "-8px "),
          #("transition", "transform 0.3s ease"),
        ]),
        a.attribute("width", "100vw"),
        a.attribute("height", "100vh"),
      ],
      [
        // svg.g(
        //   [
        //     a.attribute("transform", component.translate(w, h) <> "scale(3.0)"),
        //   ],
        //   ps,
        // ),
        keyed.namespaced(
          "http://www.w3.org/2000/svg",
          "g",
          [
            a.attribute("transform", component.translate(w, h) <> "scale(3.0)"),
            a.style("transition", "transform 0.3s ease"),
          ],
          ps,
        ),
      ],
    )
  h.html([], [
    head,
    board,
  ])
}

@external(javascript, "./ffi.js", "windowWidth")
pub fn window_width() -> Float

@external(javascript, "./ffi.js", "windowHeight")
pub fn window_height() -> Float
