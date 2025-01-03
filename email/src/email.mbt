///| Structure holding an email sender's configuration
pub(all) struct Email {
  list_worker_urn : String
}

///| Run the email sending loop
pub fn run(self : Email) -> Unit {
  while true {
    match self.get_deadline() {
      Some(epoch_ms) => {
        let now = @wallClock.now()
        let now_ms = now.seconds * 1000 +
          (now.nanoseconds.reinterpret_as_int() / 1000000).to_uint64()
        let duration_ms = epoch_ms.reinterpret_as_int64() -
          now_ms.reinterpret_as_int64()
        if duration_ms > 0 {
          sleep(duration_ms.reinterpret_as_uint64())
        } else {
          let recipients = self.get_recipients();
          @logging.log(@logging.Level::INFO, "", "Sending emails to recipients: \{recipients}")
          match send_emails?(recipients) {
            Ok(_) => @logging.log(@logging.Level::INFO, "", "Sending emails succeeded")
            Err(error) => @logging.log(@logging.Level::ERROR, "", "Failed to send emails: \{error}")
          }
        }
        continue
      }
      None => break
    }
  }
}

///| Get the current deadline from the associated list worker
fn get_deadline(self : Email) -> UInt64? {
  let api = @stubLst.EmailQuery::email_query({ value: self.list_worker_urn })
  api.blocking_deadline()
}

///| Get the current list of recipients from the associated list worker
fn get_recipients(self : Email) -> Array[String] {
  let api = @stubLst.EmailQuery::email_query({ value: self.list_worker_urn })
  api.blocking_recipients()
}

///| Sleep for the given amount of milliseconds
fn sleep(ms : UInt64) -> Unit {
  let ns = ms * 1000000
  let pollable = @monotonicClock.subscribe_duration(ns)
  let _ = @poll.poll([pollable])

}
