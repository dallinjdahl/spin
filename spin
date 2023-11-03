#!/bin/sh

# I can't reorder the content of this file, so comments will have to do.
# This is intended to be a very simple literate-programming tool.
# It has only been tested on single files, although preliminary
# provisions to supporting a list of files have been made.  It's
# currently configured to take troff formatted c source code, and
# extract all the code out.  The formatting is expected to be done
# by troff, and is out of scope of this program.

# The main principle of this tool is that you should still write
# readable code.  You should use the language facilities for abstraction
# to make everything flow nicely, and you should keep definitions
# short and self-contained.  This tool is intended to provide a way
# to explain engineering tradeoffs in the chosen implementation, and
# as a way to eliminate the ordering imposed by the compiler.  To
# that effect, we perform a topological sort on all the chunks, with
# the dependencies manually specified.  This should allow you to
# explain the program in whatever order seems best, while still making
# it compilable.

# It could be possible to automatically identify definitions and
# dependencies, but it would be language specific.  Rather than trying
# to support a whole bunch of languages, we keep it simple and agnostic
# by making it manually specified.

# In the future, I'd like to make this tool handle a n-to-m
# correspondence of literate to tangled source, but right now it's
# definitely one-to-one, and maybe n-to-one.

# Note that this is intended to be as portable as possible, and so
# we don't use functions, although the clarity clearly suffers.  As
# a basic development tool, it should be available in as many places
# as possible, and so we document a little more than would otherwise
# be needed.

# The expected invocation of this program just takes the literate
# source file as it's only parameter:
#    spin [source.lit]
awk '
BEGIN {

# These allow you to adjust the format to your liking.  Note that
# they are regexes encoded as string literals, hence the doubly escaped
# periods.  The default format is setup to work well in a troff
# environment, but any regex will work, as long as they are all unique.
# Note that the start line is expected to be followed by a name that
# it is defining, and the deps line is expected to be followed by the
# names the current definition depends on.

	start = "^\\.CS"
	end = "^\\.CE"
	dependencies = "^\\.CU"

# lineset is defined to enable resetting line numbers and filenames
# as in the C preprocessor #line directives.  If this is set to the
# empty string, this functionality will be disabled.

	correlate = "#line "
}



($0 ~ start), ($0 ~ end) {
	if($0 ~ start) {
		subject = $2
		if (correlate != "") {

# For the C preprocessor, the filename needs to be encoded as a string literal.

			file = "\"" FILENAME "\""
			node[subject] = node[subject] "\n" correlate NR file
		}
		predecessors[subject] = predecessors[subject]
		next
	}

# The following lines build up the DAG of dependencies.  To enable
# the topological sort, we count how many predecessors each node has,
# as well as a list of the successors of each node.

	if ($0 ~ dependencies) {
		for(i = 2; i <= NF; i++) {
			component = $i
			predecessors[subject]++
			successors[component]++
			graph[component "-" successors[component]] = subject
		}
		next
	}
	if ($0 ~ end) next

	node[subject] = node[subject] "\n" $0
}

# This is the bulk of the algorithm, and comes from this ACM paper:
# https://dl.acm.org/doi/pdf/10.1145/3812.315108
END {
	qback = 1
	for (i in predecessors) {
		total++
		if (predecessors[i] == 0) {
			qfront++
			q[qfront] = i
		}
	}
	while ( qback <= qfront ) {
		subject = q[qback]
		qback++
		print node[subject]
		for (i = 1; i <= successors[subject]; i++) {
			successor = graph[subject "-" i]
			predecessors[successor]--
			if (predecessors[successor] == 0) {
				qfront++
				q[qfront] = successor
			}
		}
	}
	if (qfront != total) exit 1
} ' "$@"