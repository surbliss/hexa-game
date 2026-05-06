//// Module for rendering-logic for pieces and indicators

import gleam/float
import gleam/int
import lustre/attribute as a
import lustre/element.{type Element}
import lustre/element/svg
import lustre/event

pub type Of2 {
  FirstOf2
  SecondOf2
}

pub type Of3 {
  FirstOf3
  SecondOf3
  ThirdOf3
}

pub type Piece {
  Orange(player: Player)
  // IDs below destinguish _which_ of the pieces it is, when there are multiple of the same one
  Purple(player: Player, id: Of2)
  Red(player: Player, id: Of2)
  Green(player: Player, id: Of3)
  Blue(player: Player, id: Of3)
}

pub type Player {
  Player1
  Player2
}

pub type Location {
  Location(x: Int, y: Int, z: Int)
}

pub fn piece(
  piece: Piece,
  location: Location,
  on_click: fn(Piece) -> msg,
) -> Element(msg) {
  let Location(x, y, z) = location
  let #(x, y) = get_hex_coord(x, y, z)
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
    // a.attribute("transform", "translate(-12, -12)"),
    event.on_click(on_click(piece)),
    a.styles([
      #("pointer-events", "all"),
      #("stroke-width", "2"),
      #("stroke-linejoin", "round"),
      #("transition", "transform 0.3s ease"),
    ]),
    a.attribute(
      "d",
      "M2.46148 12.8001C2.29321 12.5087 2.20908 12.3629 2.17615 12.208C2.14701 12.0709 2.14701 11.9293 2.17615 11.7922C2.20908 11.6373 2.29321 11.4915 2.46148 11.2001L6.53772 4.13984C6.70598 3.8484 6.79011 3.70268 6.90782 3.5967C7.01196 3.50293 7.13465 3.43209 7.26793 3.38879C7.41856 3.33984 7.58683 3.33984 7.92336 3.33984H16.0758C16.4124 3.33984 16.5806 3.33984 16.7313 3.38879C16.8645 3.43209 16.9872 3.50293 17.0914 3.5967C17.2091 3.70268 17.2932 3.8484 17.4615 4.13984L21.5377 11.2001C21.706 11.4915 21.7901 11.6373 21.823 11.7922C21.8522 11.9293 21.8522 12.0709 21.823 12.208C21.7901 12.3629 21.706 12.5087 21.5377 12.8001L17.4615 19.8604C17.2932 20.1518 17.2091 20.2975 17.0914 20.4035C16.9872 20.4973 16.8645 20.5681 16.7313 20.6114C16.5806 20.6604 16.4124 20.6604 16.0758 20.6604H7.92336C7.58683 20.6604 7.41856 20.6604 7.26793 20.6114C7.13465 20.5681 7.01196 20.4973 6.90782 20.4035C6.79011 20.2975 6.70598 20.1518 6.53772 19.8604L2.46148 12.8001Z",
    ),
    a.attribute("transform", translate(x, y)),
    a.attribute("stroke", stroke),
    a.attribute("fill", fill),
  ])
}

// Calculated manually
const sqrt3 = 1.732050808

fn get_hex_coord(x: Int, y: Int, z: Int) -> #(Float, Float) {
  let x = int.to_float(x)
  let y = int.to_float(y)
  let z = int.to_float(z)
  let scale = 20.0
  let hex_x = { x /. 2.0 } *. sqrt3 +. z *. 0.07 |> echo
  let hex_y = y +. x /. 2.0 +. z *. 0.12
  #(hex_x *. scale, float.negate(hex_y *. scale))
}

pub fn translate(x: Float, y: Float) -> String {
  " translate(" <> float.to_string(x) <> "," <> float.to_string(y) <> ") "
}
