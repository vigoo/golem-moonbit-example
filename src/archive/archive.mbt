///| Unique name of a document
pub type DocumentName String derive(Eq, Hash)

///| Show instance for DocumentName
impl Show for DocumentName with output(self, logger) { self._.output(logger) }

///| A single archived immutable document, encapsulating the document's name and its items
struct ArchivedDocument {
  name : DocumentName
  items : Array[String]
} derive(Show)

///| Archive is a list of archived documents
struct Archive {
  documents : Map[DocumentName, ArchivedDocument]
}

///| Creates an empty archive
fn Archive::new() -> Archive {
  { documents: Map::new() }
}

///| Archives a named document
pub fn insert(
  self : Archive,
  name : DocumentName,
  items : Array[String]
) -> Unit {
  self.documents.set(name, { name, items })
}

///| Iterates all the archived documents
pub fn iter(self : Archive) -> Iter[ArchivedDocument] {
  self.documents.values()
}

test "can archive items" {
  let result = Archive::new()
    ..insert(DocumentName("a"), ["x", "y", "z"])
    ..insert(DocumentName("b"), ["a", "b"])
    .iter()
    .to_array()
  inspect!(
    result,
    content=
      #|[{name: "a", items: ["x", "y", "z"]}, {name: "b", items: ["a", "b"]}]
    ,
  )
}
