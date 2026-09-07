/// `***` + last 4 chars of a server-assigned id (case, escrow, party).
///
/// Dispute screens must never surface a full entity/case id (EP-02-17 §11);
/// this is the single formatting helper for that rule.
String idRefSuffix(String id) {
  if (id.length <= 4) return '***$id';
  return '***${id.substring(id.length - 4)}';
}