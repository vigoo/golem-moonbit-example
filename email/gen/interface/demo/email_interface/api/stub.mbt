// Generated by `wit-bindgen` 0.36.0.

///|
pub fn send_email(list_uri : @types.Uri) -> Unit {
  let email : @src.Email = { list_worker_urn: list_uri.value }
  email.run()
}
