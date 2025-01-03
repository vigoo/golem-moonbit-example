///|
const AUTHORITY : String = "api.sendgrid.com"

///|
const PATH : String = "/v3/mail/send"

///|
type! HttpClientError String derive (Show)

///| Constructs a SendGrid send message payload as an ASCII byte array
fn payload(recipients : Array[String]) -> FixedArray[Byte]!HttpClientError {
  let email_addresses = recipients
    .iter()
    .map(fn(email) { { "email": email, "name": email } })
    .to_array()
    .to_json()
  let from : Json = { "email": "demo@vigoo.dev", "name": "Daniel Vigovszky" }
  let json : Json = {
    "personalizations": [{ "to": email_addresses, "cc": [], "bcc": [] }],
    "from": from,
    "subject": "Collaborative list editor warning",
    "content": [
      {
        "type": "text/html",
        "value": "<p>The list opened for editing has not been changed in the last 12 hours</p>",
      },
    ],
  }
  let json_str = json.to_string()
  string_to_ascii!("constructed JSON body", json_str)
}

///| Gets the SENDGRID_API_KEY environment variable as an  ASCII byte array
fn authorization_header() -> FixedArray[Byte]!HttpClientError {
  let key_str = @environment.get_environment()
    .iter()
    .find_first(fn(pair) { pair.0 == "SENDGRID_API_KEY" })
    .map(fn(pair) { pair.1 })
    .unwrap()
  string_to_ascii!(
    "provided authorization header via SENDGRID_API_KEY", key_str,
  )
}

///| Converts a string to ASCII byte array if all characters are ASCII characters, otherwise fails
fn string_to_ascii(
  what : String,
  value : String
) -> FixedArray[Byte]!HttpClientError {
  let result = FixedArray::makei(value.length(), fn(_) { b' ' })
  for i, ch in value {
    if ch.to_int() < 256 {
      result[i] = ch.to_int().to_byte()
    } else {
      raise HttpClientError("The \{what} contains non-ASCII characters")
    }
  }
  result
}

///| Send the notification to the list of email addresses
fn send_emails(recipients : Array[String]) -> Unit!HttpClientError {
  let headers = @httpTypes.Fields::fields()
  headers
  .append("Authorization", authorization_header!())
  .map_err(fn(error) {
    HttpClientError("Failed to set Authorization header: \{error}")
  })
  .unwrap_or_error!()
  let request = @httpTypes.OutgoingRequest::outgoing_request(headers)
  request
  .set_authority(Some(AUTHORITY))
  .map_err(fn(_) { HttpClientError("Failed to set request authority") })
  .unwrap_or_error!()
  request
  .set_method(@httpTypes.Method::Post)
  .map_err(fn(_) { HttpClientError("Failed to set request method") })
  .unwrap_or_error!()
  request
  .set_path_with_query(Some(PATH))
  .map_err(fn(_) { HttpClientError("Failed to set request path") })
  .unwrap_or_error!()
  request
  .set_scheme(Some(@httpTypes.Scheme::Https))
  .map_err(fn(_) { HttpClientError("Failed to set request scheme") })
  .unwrap_or_error!()
  let outgoing_body = request
    .body()
    .map_err(fn(_) { HttpClientError("Failed to get the outgoing body") })
    .unwrap_or_error!()
  let stream = outgoing_body
    .write()
    .map_err(fn(_) {
      HttpClientError("Failed to open the outgoing body stream")
    })
    .unwrap_or_error!()
  let _ = stream
    .blocking_write_and_flush(payload!(recipients))
    .map_err(fn(error) {
      HttpClientError("Failed to write request body: \{error}")
    })
    .unwrap_or_error!()
  let _ = outgoing_body
    .finish(None)
    .map_err(fn(_) { HttpClientError("Failed to close the outgoing body") })
    .unwrap_or_error!()
  let future_incoming_response = @outgoingHandler.handle(request, None)
    .map_err(fn(error) { HttpClientError("Failed to send request: \{error}") })
    .unwrap_or_error!()
  while true {
    match future_incoming_response.get() {
      Some(Ok(Ok(response))) => {
        let status = response.status()
        if status >= 200 && status < 300 {
          break
        } else {
          raise HttpClientError("Http request returned with status \{status}")
        }
      }
      Some(Ok(Err(code))) =>
        raise HttpClientError("Http request failed with \{code}")
      Some(Err(_)) => raise HttpClientError("Http request failed")
      None => {
        let pollable = future_incoming_response.subscribe()
        let _ = @poll.poll([pollable])

      }
    }
  }
}
