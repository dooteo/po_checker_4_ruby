# po_checker_4_ruby
Awk script to check out whether vars in msgid are in msgstr too for Ruby

There is a issue when it comes to check vars consistency between 
msgid and msgstr messages for programs developed in Ruby language:
nor gettext's **msgfmt** (0.19.8.1) neither **rmsgfmt** (3.2.2) does check 
vars consistency into PO files for Ruby programs.

This could lead to translators make mistakes that could affect negatively 
program's quality.

This script help translators to take care about those kind of errors/mistakes.

# Usage:
  *msg_ruby_po_checker.awk INPUT_RUBY_POFILE*
  or
  *msg_ruby_po_checker.awk INPUT_RUBY_POFILE OUTPUT_LOGFILE*
