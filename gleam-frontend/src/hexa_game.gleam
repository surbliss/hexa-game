import lustre
import mvu/model
import mvu/view

pub fn main() {
  let app = lustre.simple(model.init, model.update, view.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
