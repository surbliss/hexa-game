//// Module for rendering-logic for pieces and indicators

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/element/svg
import lustre/event
import mvu/types.{
  type Location, type Message, type Model, type Piece, Blue, ClientClickedPiece,
  FirstOf2, FirstOf3, Green, Location, Orange, Player1, Player2, Purple, Red,
  SecondOf2, SecondOf3, ThirdOf3,
}

// Public

pub fn view(model: Model) -> Element(Message) {
  h.html([], [
    head(),
    board(model.pieces),
  ])
}

// Private helper functionw
fn head() {
  h.head([], [
    h.link([a.rel("icon"), a.href("data:,")]),
    h.meta([
      a.name("viewport"),
      a.content("width=device-width, initial-scale=1"),
    ]),
    h.title([], "Hexa-game"),
    h.style([], "path:active { filter: brightness(0.7); }"),
  ])
}

fn board(pieces: Dict(Piece, Location)) -> Element(Message) {
  let w = window_width() /. 2.0
  let h = window_height() /. 2.0
  let pieces_list = dict.to_list(pieces)
  let paths =
    pieces_list
    |> list.map(fn(x) {
      let #(p, l) = x
      piece_path(p, l)
    })
  let uses =
    pieces_list
    |> list.sort(fn(x, y) { int.compare(x.1.z, y.1.z) })
    |> list.map(fn(x) {
      let #(p, l) = x
      piece_use(p, l)
    })
  let pieces = list.flatten([paths, uses])
  // pieces
  // |> dict.to_list
  // |> list.flat_map(fn(x) {
  //   let #(p, l) = x
  //   [piece_path(p, l), piece_use(p)]
  // })

  svg.svg(
    [
      a.styles([
        #("background", "blanchedalmond"),
        #("display", "flex"),
        #("justify-content", "center"),
        #("align-items", "center"),
        #("height", "100vh"),
        #("margin", "-8px "),
      ]),
      a.attribute("width", "100vw"),
      a.attribute("height", "100vh"),
    ],
    [
      svg.g(
        [
          a.attribute("transform", translate(w, h) <> "scale(3.0)"),
          a.style("opacity", "0"),
          a.style("transition", "transform 0.3s ease"),
        ],
        // {
        //   let zs =
        //     pieces
        //     |> list.map(fn(x) { x.1.z })
        //     |> list.sort(int.compare)
        //     |> list.unique
        //   zs
        //   |> list.map(fn(z) {
        //     let layer = pieces |> list.filter(fn(x) { x.1.z == z })
        //     svg.g([], list.map(layer, fn(x) { piece(x.0, x.1) }))
        //   })
        // }
        paths,
      ),
      svg.g(
        [
          a.attribute("transform", translate(w, h) <> "scale(3.0)"),
          a.style("opacity", "1"),
          a.style("transition", "transform 0.3s ease"),
        ],
        uses,
      ),
    ],
  )
}

fn piece_path(piece: Piece, _location: Location) -> Element(Message) {
  // let Location(x, y, z) = location
  // let #(x, y) = get_hex_coord(x, y, z)
  let fill = case piece.player {
    Player1 -> "white"
    Player2 -> "black"
  }
  let stroke = case piece {
    Orange(_) -> "orange"
    Purple(_, _) -> "mediumpurple"
    Red(_, _) -> "indianred"
    Green(_, _) -> "darkseagreen"
    Blue(_, _) -> "cornflowerblue"
  }
  svg.path([
    a.styles([
      #("pointer-events", "all"),
      #("stroke-width", "2"),
      #("stroke-linejoin", "round"),
      #("transition", "transform 0.3s ease"),
      // #("opacity", ".5"),
    ]),
    a.id(piece_id(piece)),
    a.attribute(
      "d",
      "M2.46148 12.8001C2.29321 12.5087 2.20908 12.3629 2.17615 12.208C2.14701 12.0709 2.14701 11.9293 2.17615 11.7922C2.20908 11.6373 2.29321 11.4915 2.46148 11.2001L6.53772 4.13984C6.70598 3.8484 6.79011 3.70268 6.90782 3.5967C7.01196 3.50293 7.13465 3.43209 7.26793 3.38879C7.41856 3.33984 7.58683 3.33984 7.92336 3.33984H16.0758C16.4124 3.33984 16.5806 3.33984 16.7313 3.38879C16.8645 3.43209 16.9872 3.50293 17.0914 3.5967C17.2091 3.70268 17.2932 3.8484 17.4615 4.13984L21.5377 11.2001C21.706 11.4915 21.7901 11.6373 21.823 11.7922C21.8522 11.9293 21.8522 12.0709 21.823 12.208C21.7901 12.3629 21.706 12.5087 21.5377 12.8001L17.4615 19.8604C17.2932 20.1518 17.2091 20.2975 17.0914 20.4035C16.9872 20.4973 16.8645 20.5681 16.7313 20.6114C16.5806 20.6604 16.4124 20.6604 16.0758 20.6604H7.92336C7.58683 20.6604 7.41856 20.6604 7.26793 20.6114C7.13465 20.5681 7.01196 20.4973 6.90782 20.4035C6.79011 20.2975 6.70598 20.1518 6.53772 19.8604L2.46148 12.8001Z",
    ),
    // a.attribute("transform", translate(x, y)),
    a.attribute("stroke", stroke),
    a.attribute("fill", fill),
  ])
}

fn piece_use(piece: Piece, location: Location) -> Element(Message) {
  let Location(x, y, z) = location
  let #(x, y) = get_hex_coord(x, y, z)
  svg.use_([
    event.on_click(ClientClickedPiece(piece)),
    a.attribute("transform", translate(x, y)),
    a.href("#" <> piece_id(piece)),
  ])
}

// Calculated manually
const sqrt3 = 1.732050808

fn get_hex_coord(x: Int, y: Int, z: Int) -> #(Float, Float) {
  let x = int.to_float(x)
  let y = int.to_float(y)
  let z = int.to_float(z)
  let scale = 20.0
  let hex_x = { x /. 2.0 } *. sqrt3 +. z *. 0.07
  let hex_y = y +. x /. 2.0 +. z *. 0.12
  #(hex_x *. scale, float.negate(hex_y *. scale))
}

fn translate(x: Float, y: Float) -> String {
  " translate(" <> float.to_string(x) <> "," <> float.to_string(y) <> ") "
}

fn piece_id(piece: Piece) -> String {
  let two_id = fn(x) {
    case x {
      FirstOf2 -> "1"
      SecondOf2 -> "2"
    }
  }
  let three_id = fn(x) {
    case x {
      FirstOf3 -> "1"
      SecondOf3 -> "2"
      ThirdOf3 -> "3"
    }
  }
  let player_id = case piece.player {
    Player1 -> "p1"
    Player2 -> "p2"
  }
  let pid = case piece {
    Orange(..) -> "o"
    Purple(_, id:) -> "p" <> two_id(id)
    Red(_, id:) -> "r" <> two_id(id)
    Green(_, id:) -> "g" <> three_id(id)
    Blue(_, id:) -> "b" <> three_id(id)
  }
  pid <> "-" <> player_id
}

// FFI
@external(javascript, "./ffi.js", "windowWidth")
fn window_width() -> Float

@external(javascript, "./ffi.js", "windowHeight")
fn window_height() -> Float
// fn piece(piece: Piece, location: Location) -> Element(Message) {
//   let Location(x, y, z) = location
//   let #(x, y) = get_hex_coord(x, y, z)
//   let fill = case piece.player {
//     Player1 -> "white"
//     Player2 -> "black"
//   }
//   let stroke = case piece {
//     Orange(_) -> "orange"
//     Purple(_, _) -> "mediumpurple"
//     Red(_, _) -> "indianred"
//     Green(_, _) -> "darkseagreen"
//     Blue(_, _) -> "cornflowerblue"
//   }
//   svg.path([
//     event.on_click(ClientClickedPiece(piece)),
//     a.styles([
//       #("pointer-events", "all"),
//       #("stroke-width", "2"),
//       #("stroke-linejoin", "round"),
//       #("transition", "transform 0.3s ease"),
//       #("visibility", "visible"),
//     ]),
//     a.id(piece_id(piece)),
//     a.attribute(
//       "d",
//       "M2.46148 12.8001C2.29321 12.5087 2.20908 12.3629 2.17615 12.208C2.14701 12.0709 2.14701 11.9293 2.17615 11.7922C2.20908 11.6373 2.29321 11.4915 2.46148 11.2001L6.53772 4.13984C6.70598 3.8484 6.79011 3.70268 6.90782 3.5967C7.01196 3.50293 7.13465 3.43209 7.26793 3.38879C7.41856 3.33984 7.58683 3.33984 7.92336 3.33984H16.0758C16.4124 3.33984 16.5806 3.33984 16.7313 3.38879C16.8645 3.43209 16.9872 3.50293 17.0914 3.5967C17.2091 3.70268 17.2932 3.8484 17.4615 4.13984L21.5377 11.2001C21.706 11.4915 21.7901 11.6373 21.823 11.7922C21.8522 11.9293 21.8522 12.0709 21.823 12.208C21.7901 12.3629 21.706 12.5087 21.5377 12.8001L17.4615 19.8604C17.2932 20.1518 17.2091 20.2975 17.0914 20.4035C16.9872 20.4973 16.8645 20.5681 16.7313 20.6114C16.5806 20.6604 16.4124 20.6604 16.0758 20.6604H7.92336C7.58683 20.6604 7.41856 20.6604 7.26793 20.6114C7.13465 20.5681 7.01196 20.4973 6.90782 20.4035C6.79011 20.2975 6.70598 20.1518 6.53772 19.8604L2.46148 12.8001Z",
//     ),
//     a.attribute("transform", translate(x, y)),
//     a.attribute("stroke", stroke),
//     a.attribute("fill", fill),
//   ])
// }
