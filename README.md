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

# Note about 'false positve' errors:

A kind of errors could be shown when, for a given language, a 
correct translated message does not use one or more vars. 

Ruby has no issues when a substitution variable is not present in the
string: its value will be just omitted from the resulting output.
Hence, it's not wrong for a translation to not explicitly specify the
number, whenever it can be clearly inferred from the use of the form in
use.

For example, let's see a message like:
<pre>
msgid ""
"The following %{nbugs} bug will be dodged:\n"
" %{blist}\n"
"Are you sure?"
msgid_plural ""
"The following %{nbugs} bugs will be dodged:\n"
" %{blist}\n"
"Are you sure?"
msgstr[0] ""
"Il seguente bug verrà evitato:\n"
" %{blist}\n"
"Si è sicuri?"
msgstr[1] ""
"I seguenti %{nbugs} bug verranno evitati:\n"
" %{blist}\n"
"Si è sicuri?"
</pre>
That message is properly translated, even it has not contain %{nbugs} 
variable for msgstr[0] case. 

But this script will show a 'false positive' error message:
<pre>
Error at message ID: 59     [line: 366]  <<<<
Error: different vars numbers. Msgid has: 2 != Msgstr has 1
---- ---- Message: ---- ---- <<<<
msgid ""
"The following %{nbugs} bug will be dodged:\n"
" %{blist}\n"
"Are you sure?"
msgid_plural ""
"The following %{nbugs} bugs will be dodged:\n"
" %{blist}\n"
"Are you sure?"
msgstr[0] ""
"Il seguente bug verrà evitato:\n"
" %{blist}\n"
"Si è sicuri?"
msgstr[1] ""
"I seguenti %{nbugs} bug verranno evitati:\n"
" %{blist}\n"
"Si è sicuri?"
---- ---- ---- ---- <<<<
</pre>

This corner case is too complicated to solve. I’d rather let script as it is, 
and consider those cases as ‘false positives’. Otherwise, it wont show errors 
related to wrong var names in msgstr translations.

