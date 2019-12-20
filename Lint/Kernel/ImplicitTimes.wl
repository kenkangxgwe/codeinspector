BeginPackage["Lint`ImplicitTimes`"]

ImplicitTimesFile

ImplicitTimesString



ImplicitTimesFileReport

ImplicitTimesStringReport




Begin["`Private`"]

Needs["AST`"]
Needs["AST`Abstract`"]
Needs["Lint`"]
Needs["Lint`Report`"]
Needs["Lint`Format`"]
Needs["Lint`Utils`"]




ImplicitTimesFile::usage = "ImplicitTimesFile[file, options] returns a list of implicit times in file."

Options[ImplicitTimesFile] = {
  PerformanceGoal -> "Speed"
}


$fileByteCountMinLimit = 0*^6
$fileByteCountMaxLimit = 3*^6



ImplicitTimesFile[file_, OptionsPattern[]] :=
Catch[
 Module[{full, times, performanceGoal, cst, agg},

 performanceGoal = OptionValue[PerformanceGoal];

   full = FindFile[file];
  If[FailureQ[full],
    Throw[Failure["FindFileFailed", <|"FileName"->file|>]]
  ];

   If[performanceGoal == "Speed",
    If[FileByteCount[full] > $fileByteCountMaxLimit,
     Throw[Failure["FileTooLarge", <|"FileName"->full, "FileSize"->FileSize[full]|>]]
     ];
    If[FileByteCount[full] < $fileByteCountMinLimit,
     Throw[Failure["FileTooSmall", <|"FileName"->full, "FileSize"->FileSize[full]|>]]
     ];
    ];

    cst = ConcreteParseFile[full];

    If[FailureQ[cst],
      Throw[cst]
    ];

    agg = Aggregate[cst];

    times = implicitTimes[agg];

   times
]]





ImplicitTimesString::usage = "ImplicitTimesString[string, options] returns a list of implicit times in string."

Options[ImplicitTimesString] = {
  PerformanceGoal -> "Speed"
}

ImplicitTimesString[string_, OptionsPattern[]] :=
Catch[
 Module[{times, cst, agg},

   cst = ConcreteParseString[string];

   If[FailureQ[cst],
    Throw[cst]
  ];

  agg = Aggregate[cst];

    times = implicitTimes[agg];

   times
]]












ImplicitTimesFileReport::usage = "ImplicitTimesFileReport[file, implicitTimes, options] returns a LintedFile object."

Options[ImplicitTimesFileReport] = {
  "LineNumberExclusions" -> <||>,
  "LineHashExclusions" -> {}
}




ImplicitTimesFileReport[file_String, implicitTimesIn:{___InfixNode}:Automatic, OptionsPattern[]] :=
Catch[
 Module[{implicitTimes, full, lines, lineNumberExclusions, lineHashExclusions, lintedLines},

 implicitTimes = implicitTimesIn;

 lineNumberExclusions = OptionValue["LineNumberExclusions"];
 lineHashExclusions = OptionValue["LineHashExclusions"];

   full = FindFile[file];
  If[FailureQ[full],
    Throw[Failure["FindFileFailed", <|"FileName"->file|>]]
  ];

   If[FileByteCount[full] == 0,
   Throw[Failure["EmptyFile", <|"FileName"->full|>]]
   ];

   If[implicitTimes === Automatic,
    implicitTimes = ImplicitTimesFile[full];
    ];

   (*
    bug 163988
    Use CharacterEncoding -> "ASCII" to guarantee that newlines are preserved
    *)
   lines = Import[full, {"Text", "Lines"}, CharacterEncoding -> "ASCII"];

   lintedLines = implicitTimesLinesReport[lines, implicitTimes, lineNumberExclusions, lineHashExclusions];
   LintedFile[full, lintedLines]
]]




ImplicitTimesStringReport::usage = "ImplicitTimesStringReport[string, implicitTimes, options] returns a LintedString object."

Options[ImplicitTimesStringReport] = {
  "LineNumberExclusions" -> <||>,
  "LineHashExclusions" -> {}
}

ImplicitTimesStringReport[string_String, implicitTimesIn:{___InfixNode}:Automatic, OptionsPattern[]] :=
Catch[
 Module[{implicitTimes, lines, lineNumberExclusions, lineHashExclusions, lintedLines},

 implicitTimes = implicitTimesIn;

 lineNumberExclusions = OptionValue["LineNumberExclusions"];
 lineHashExclusions = OptionValue["LineHashExclusions"];

 If[StringLength[string] == 0,
  Throw[Failure["EmptyString", <||>]]
 ];

  If[implicitTimes === Automatic,
    implicitTimes = ImplicitTimesString[string];
  ];

    (*
    bug 163988
    Use CharacterEncoding -> "ASCII" to guarantee that newlines are preserved
    *)
   lines = ImportString[string, {"Text", "Lines"}, CharacterEncoding -> "ASCII"];

   lintedLines = implicitTimesLinesReport[lines, implicitTimes, lineNumberExclusions, lineHashExclusions];
   LintedString[string, lintedLines]
]]





implicitTimes[agg_] :=
Catch[
Module[{implicitTimes},

  implicitTimes = Cases[agg, InfixNode[Times, nodes_ /; !FreeQ[nodes, LeafNode[Token`Fake`ImplicitTimes, _, _], 1], opts_], {0, Infinity}];

  implicitTimes
]]





(* how many (, ), or \[Times] to insert per line *)
$markupLimit = 100


$color = severityColor[{Lint["ImplicitTimes", "ImplicitTimes", "ImplicitTimes", <||>]}];


modify[lineIn_String, {starts_, ends_, infixs_}, lineNumber_] :=
 Module[{line, startCols, endCols, infixCols, startInserters, endInserters, infixInserters, under,
  rules, underLength},

  startCols = Cases[starts, {lineNumber, col_} :> col];
  endCols = Cases[ends, {lineNumber, col_} :> col];
  infixCols = Cases[infixs, {lineNumber, col_} :> col];

  line = lineIn;

  startInserters = AssociationMap[LintMarkup["(", FontWeight->Bold, FontSize->Larger, FontColor->$color]&, startCols];
  endInserters = AssociationMap[LintMarkup[")", FontWeight->Bold, FontSize->Larger, FontColor->$color]&, endCols];
  infixInserters = AssociationMap[LintMarkup[LintTimes, FontWeight->Bold, FontSize->Larger, FontColor->$color]&, infixCols];

  If[$Debug,
    Print["lineNumber: ", lineNumber];
    Print["startInserters: ", startInserters];
    Print["endInserters: ", endInserters];
    Print["infixInserters: ", infixInserters];
  ];

  If[Intersection[Keys[startInserters], Keys[endInserters]] =!= {},
    Throw["intersection start and end", "Unhandled"]
  ];

  If[Intersection[Keys[startInserters], Keys[infixInserters]] =!= {},
    Throw["intersection start and infix", "Unhandled"]
  ];

  If[Intersection[Keys[endInserters], Keys[infixInserters]] =!= {},
    Throw["intersection end and infix", "Unhandled"]
  ];

  rules = Join[startInserters, endInserters, infixInserters];
  rules = Normal[rules];

  underLength = StringLength[line];
  (*
  extend line to be able to insert \[Times] after the line, when ImplicitTimes spans lines
  *)
  underLength = underLength + 1;
  under = Table[" ", {underLength}];

  under = ReplacePart[under, rules];

  (*
  to match Listify
  *)
  under = Join[{" "}, under];

  under
  ]

(*
return {line, col} for all \[Times] symbols
*)
processPar[{left_, LeafNode[Token`Fake`ImplicitTimes, _, _], right_}] :=
 Module[{leftSource, rightSource},

  leftSource = left[[3, Key[Source] ]];
  rightSource = right[[3, Key[Source] ]];
   (*
   same line
   
   this is symbolically represented as the best placement between left and right at this stage

   Actual tokenization needs to occur later to figure out the actual column
   *)
   BestImplicitTimesPlacement[{leftSource[[2]], rightSource[[1]]}]
   ]

(*
other tokens in InfixNode[Time, ] such as LeafNode[Token`Star]
*)
processPar[_] := Nothing


(*
nodes is something like { 1, ImplicitTimes, 2 } and we just want {1, 2} pairs

we will disregard the ImplicitTimes tokens that come in, because they may not have Source that looks good
*)
processChildren[nodes_List] :=
 Module[{pars},

  If[$Debug,
    Print["processChildren nodes: ", nodes];
  ];

  pars = Partition[nodes, 3, 2];
  processPar /@ pars
  ]

implicitTimesLinesReport[linesIn:{___String}, implicitTimesIn:{___InfixNode}, lineNumberExclusionsIn_Association, lineHashExclusionsIn_List] :=
Catch[
 Module[{implicitTimes, sources, starts, ends, infixs, lines, hashes,
  lineNumberExclusions, lineHashExclusions, implicitTimesExcludedByLineNumber, tmp, linesToModify},

    If[implicitTimes === {},
      Throw[{}]
    ];

    implicitTimes = implicitTimesIn;

    lines = linesIn;
    hashes = (IntegerString[Hash[#], 16, 16])& /@ lines;

    If[$Debug,
      Print["lines: ", lines];
    ];

    lineNumberExclusions = lineNumberExclusionsIn;

    lineNumberExclusions = expandLineNumberExclusions[lineNumberExclusions];

    lineHashExclusions = lineHashExclusionsIn;

    (* Association of lineNumber -> All *)
    tmp = Association[Table[If[MemberQ[lineHashExclusions, hashes[[i]]], i -> All, Nothing], {i, 1, Length[lines]}]];
    lineNumberExclusions = lineNumberExclusions ~Join~ tmp;


    (*
    implicitTimes that match the line numbers and tags in lineNumberExclusions
    *)
    implicitTimesExcludedByLineNumber = Catenate[KeyValueMap[Function[{line, tags},
        If[tags === All,
          Cases[implicitTimes, InfixNode[_, _, KeyValuePattern[Source -> {{line1_ /; line1 == line, _}, {_, _}}]]]
          ,
          (* warn? *)
          {}
        ]
      ],
      lineNumberExclusions]];

    implicitTimes = Complement[implicitTimes, implicitTimesExcludedByLineNumber];


    sources = #[Source]& /@ implicitTimes[[All, 3]];

   starts = sources[[All, 1]];
   ends = sources[[All, 2]];

   infixs = processChildren /@ implicitTimes[[All, 2]];

   If[$Debug,
    Print["infixs: ", infixs];
   ];

   infixs = Flatten[infixs, 1];

   If[$Debug,
    Print["infixs: ", infixs];
   ];

   (*
    resolve BestImplicitTimesPlacement with actual columns now
   *)
   infixs = Map[resolveInfix[#, lines]&, infixs];








   linesToModify = Union[starts[[All, 1]] ~Join~ ends[[All, 1]] ~Join~ infixs[[All, 1]]];

   Table[

     LintedLine[lines[[i]], i, hashes[[i]], {ListifyLine[lines[[i]], <||>, "EndOfFile" -> (i == Length[lines])],
                                  modify[lines[[i]], {starts, ends, infixs}, i]},
                                  {}]
    ,
    {i, linesToModify}
    ]
]]



(*

BestImplicitTimesPlacement[span_] is something like {{startLine_, startCol_}, {endLine_, endCol_}}
*)
resolveInfix[BestImplicitTimesPlacement[span_], lines:{___String}] :=
Module[{lineNumber, line, tokens, goalLine, goalCol, spaces, spaceRanges, candidates, edges, offset, intersection,
	mean, comments, gaps, excludes, goals},

  If[$Debug,
    Print["resolveInfix: ", {BestImplicitTimesPlacement[span], lines}];
  ];

  Which[
    span[[1, 1]] != span[[2, 1]],
      (* different lines, so place \[Times] at end of first line *)
      {span[[1, 1]], StringLength[lines[[span[[1, 1]] ]] ] + 1}
    ,
    span[[1, 2]] == span[[2, 2]],
      (* contiguous *)
      {span[[1, 1]], span[[1, 2]]}
    ,
    span[[1, 2]] + 1 == span[[2, 2]],
      (* optimization case to avoid calling TokenizeString: only 1 space between *)
      {span[[1, 1]], span[[1, 2]]}
    ,
    True,
      (* do actual work to figure out best placement *)
      goalLine = span[[1, 1]];
      mean = N[Mean[{span[[1, 2]], span[[2, 2]]}]];
      lineNumber = span[[1, 1]];
      line = lines[[lineNumber]];

      (* only tokenize the characters in-between *)
      line = StringTake[line, {span[[1, 2]], span[[2, 2]]-1}];

      If[$Debug,
        Print["line: ", line];
      ];

      tokens = TokenizeString[line];

      If[$Debug,
        Print["tokens: ", tokens];
      ];

      offset = span[[1, 2]];
      
      If[$Debug,
        Print["offset: ", offset];
      ];

      (*
      any space is a candidate
      *)
      spaces = Cases[tokens, LeafNode[Whitespace, _, _]];
      spaceRanges = offset - 1 + Flatten[Range @@ #[[3, Key[Source], All, 2]]& /@ spaces];
      
      If[$Debug,
        Print["spaceRanges: ", spaceRanges];
      ];

      (*
      the gaps on either side of a comment are only candidates if they are not next to a space (because the space
      itself is preferred) 
      *)
      comments = Cases[tokens, LeafNode[Token`Comment, _, _]];
      gaps = #[[3, Key[Source], 1, 2]]& /@ comments;
      excludes = SequenceCases[tokens, {LeafNode[Whitespace, _, _], c:LeafNode[Token`Comment, _, _]} :> c];
      gaps = offset - 1 + Complement[gaps, excludes];

      If[$Debug,
        Print["gaps: ", gaps];
      ];

      edges = offset - 1 + {0, StringLength[line]+1};

      If[$Debug,
        Print["edges: ", edges];
      ];

      candidates = Union[spaceRanges ~Join~ gaps ~Join~ edges];

      If[$Debug,
        Print["candidates: ", candidates];
      ];

      (*
      Which candidates are closest to mean?
      *)
      goals = MinimalBy[candidates, Abs[# - mean]&];

      If[$Debug,
        Print["goals: ", goals];
      ];

      Which[
        Length[goals] == 1,
        (* only 1 possibility *)
        goalCol = goals[[1]];
        ,
        intersection = Intersection[goals, spaceRanges];
        intersection =!= {}
        ,
        (* always prefer spaces over gaps or edges *)
        goalCol = intersection[[1]];
        ,
        True,
        (* only comments; arbitrarily choose one *)
        goalCol = goals[[1]];
      ];

      {goalLine, goalCol}
  ]]

resolveInfix[infix_, lines:{___String}] :=
  infix



End[]

EndPackage[]
