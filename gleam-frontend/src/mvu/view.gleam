//// Module for rendering-logic for pieces and indicators

import gleam/dict.{type Dict}
import gleam/float
import gleam/int
import gleam/list
import gleam/string
import lustre/attribute.{type Attribute} as a
import lustre/element.{type Element}
import lustre/element/html as h
import lustre/element/svg
import lustre/event
import mvu/types.{
  type Location, type Message, type Model, type Piece, Blue, ClientClickedPiece,
  FirstOf2, FirstOf3, Green, Location, Orange, Player1, Player2, Purple, Red,
  SecondOf2, SecondOf3, ThirdOf3,
}

//-------------------------------------------------
// Public
//-------------------------------------------------

pub fn view(model: Model) -> Element(Message) {
  h.div(
    [
      a.class(
        "flex flex-col h-screen w-screen justify-center items-start select-none",
      ),
    ],
    [
      board(model.pieces),
      hand(),
    ],
  )
}

//-------------------------------------------------
// Private
//-------------------------------------------------
// Board, where all pieces and gameplay live
fn board(pieces: Dict(Piece, Location)) -> Element(Message) {
  let pieces_list = dict.to_list(pieces)
  let pieces =
    pieces_list
    |> list.map(fn(x) {
      let #(p, l) = x
      piece(p, l)
    })
  svg.svg(
    [
      a.class("bg-orange-100 w-full h-full touch-pinch-zoom overflow-auto"),
    ],
    [
      svg.g(
        // Place (0,0) in the middle of the board
        [a.class("translate-x-[50vw] translate-y-[50vh] scale-150")],
        pieces,
      ),
    ],
  )
}

// Hand for unplaced pieces
fn hand() -> Element(Message) {
  h.div([a.class("fixed bottom-0 w-full h-1/10")], [
    svg.svg(
      [a.class("w-full h-[10dvh] bg-red-100 grow touch-none overflow-auto")],
      // TODO: Place all pieces without a Location here
      [],
    ),
  ])
}

// Object-render functions
fn piece(piece: Piece, location: Location) -> Element(Message) {
  let fill = case piece.player {
    Player1 -> "fill-neutral-800 hover:fill-neutral-950 active:fill-neutral-950"
    Player2 -> "fill-neutral-50 hover:fill-neutral-100 active:fill-neutral-100"
  }
  let stroke = case piece {
    Orange(_) ->
      "stroke-amber-500 hover:stroke-amber-600 active:stroke-amber-600"
    Purple(_, _) ->
      "stroke-violet-400 hover:stroke-violet-500 active:stroke-violet-500 z-30"
    Red(_, _) ->
      "stroke-amber-700 hover:stroke-amber-800 active:stroke-amber-800"
    Green(_, _) ->
      "stroke-lime-500 hover:stroke-lime-600 active:stroke-lime-600"
    Blue(_, _) -> "stroke-sky-600 hover:stroke-sky-700 active:stroke-sky-700"
  }
  // Old CSS colors:
  // orange, mediumpurple, indianred, darkseagreen, cornflowerblue
  svg.path([
    event.on_click(ClientClickedPiece(piece)),
    place(hex_coordinate(location)),
    tw_classes([
      fill,
      stroke,
      "stroke-2",
      "origin-center",
      "scale-200",
      // Unsure about this one..
      "[transform-box:fill-box]",
      "transition duration-100",
    ]),
    a.attribute("d", hexagon_path),
  ])
}

// Helper functions for rendering objects
fn tw_classes(styles: List(String)) -> Attribute(Message) {
  styles
  |> string.join(" ")
  |> string.trim
  |> a.class
}

// Calculated manually
const sqrt3 = 1.732050808

fn hex_coordinate(location: Location) -> #(Float, Float) {
  let x = int.to_float(location.x)
  let y = int.to_float(location.y)
  let z = int.to_float(location.z)
  let scale = 20.0
  let hex_x =
    x /. 2.0 *. sqrt3 +. z *. 0.07
    |> float.multiply(scale)
    |> float.to_precision(2)
  let hex_y =
    y +. x /. 2.0 +. z *. 0.12
    |> float.multiply(scale)
    |> float.negate
    |> float.to_precision(2)
  #(hex_x, hex_y)
}

fn place(coord: #(Float, Float)) -> Attribute(Message) {
  let x = float.to_string(coord.0)
  let y = float.to_string(coord.1)
  let translate_str = "translate(" <> x <> "," <> y <> ")"
  a.attribute("transform", translate_str)
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

const hexagon_path = "M2.46148 12.8001C2.29321 12.5087 2.20908 12.3629 2.17615 12.208C2.14701 12.0709 2.14701 11.9293 2.17615 11.7922C2.20908 11.6373 2.29321 11.4915 2.46148 11.2001L6.53772 4.13984C6.70598 3.8484 6.79011 3.70268 6.90782 3.5967C7.01196 3.50293 7.13465 3.43209 7.26793 3.38879C7.41856 3.33984 7.58683 3.33984 7.92336 3.33984H16.0758C16.4124 3.33984 16.5806 3.33984 16.7313 3.38879C16.8645 3.43209 16.9872 3.50293 17.0914 3.5967C17.2091 3.70268 17.2932 3.8484 17.4615 4.13984L21.5377 11.2001C21.706 11.4915 21.7901 11.6373 21.823 11.7922C21.8522 11.9293 21.8522 12.0709 21.823 12.208C21.7901 12.3629 21.706 12.5087 21.5377 12.8001L17.4615 19.8604C17.2932 20.1518 17.2091 20.2975 17.0914 20.4035C16.9872 20.4973 16.8645 20.5681 16.7313 20.6114C16.5806 20.6604 16.4124 20.6604 16.0758 20.6604H7.92336C7.58683 20.6604 7.41856 20.6604 7.26793 20.6114C7.13465 20.5681 7.01196 20.4973 6.90782 20.4035C6.79011 20.2975 6.70598 20.1518 6.53772 19.8604L2.46148 12.8001Z"
