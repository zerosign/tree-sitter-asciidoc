const { anySep1, escaped_ch } = require('../../common/common');

exports.rules = {
  document_title: $ =>
    seq(
      optional($._block_attrs),
      $.title_h0_marker,
      $._WHITE_SPACE,
      $.line,
      optional(seq($.author_line, seq($._NEWLINE, optional($.revision_line)))),
      repeat(choice($.document_attr, $.block_macro, $.line_comment, $.block_comment)),
      $._block_end,
    ),
  author_line: $ => anySep1($.author, seq(';', $._WHITE_SPACE)),
  author: $ =>
    seq(
      alias($._author_line_word, $.firstname),
      $._WHITE_SPACE,
      optional(seq(alias($._author_line_word, $.middlename), $._WHITE_SPACE)),
      alias($._author_line_word, $.lastname),
      optional(seq($._WHITE_SPACE, '<', $.email, '>')),
    ),
  _author_line_word: $ => seq(/[^ \t\r\n:;\/]/, repeat(escaped_ch(' ;', true))),
  email: $ => repeat1(/[^>\r\n]/),
  revision_line: $ =>
    seq(
      $.revnumber,
      optional(
        seq(
          ',',
          $._WHITE_SPACE,
          $.revdate,
          optional(seq(':', $._WHITE_SPACE, $.revremark)),
        ),
      ),
    ),
  revnumber: $ => seq(/[a-zA-Z0-9{]/, repeat(escaped_ch(',', true))),
  revdate: $ => repeat1(escaped_ch(':', true)),
  revremark: $ => repeat1(/[^\r\n]/),
  document_attr: $ =>
    seq(
      $.document_attr_marker,
      alias(repeat1(escaped_ch(':', true)), $.attr_name),
      alias(':', $.document_attr_marker),
      // The value may be absent after the separating space (`:sourceFile: `),
      // so the line itself is optional too.
      optional(seq(token.immediate(' '), optional(alias($.escaped_line, $.line)))),
      $._block_end,
    ),
};
