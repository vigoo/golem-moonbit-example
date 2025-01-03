
pub struct Email {
  list_worker_urn: String
}

pub fn run(self: Email) -> Unit {
  let api = @stubLst.Api::api({ value: self.list_worker_urn });
  
}

fn getDeadline(self: Email) {

}