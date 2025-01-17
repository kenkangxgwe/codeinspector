BeginPackage["CodeInspector`Summarize`"]

ListifyLine



$DefaultConfidenceLevel

$DefaultTagExclusions

$DefaultSeverityExclusions


$LintedLineLimit

$DefaultLintLimit


$Underlight


$LineTruncationLimit


Begin["`Private`"]

Needs["CodeParser`"]
Needs["CodeParser`Utils`"]
Needs["CodeInspector`"]
Needs["CodeInspector`AbstractRules`"]
Needs["CodeInspector`AggregateRules`"]
Needs["CodeInspector`ConcreteRules`"]
Needs["CodeInspector`Format`"]
Needs["CodeInspector`Utils`"]


$DefaultTagExclusions = {}

$DefaultSeverityExclusions = {"Formatting", "Remark"}

(*
How many linted lines to keep?
*)
$LintedLineLimit = 10

(*
How many lints to keep?
*)
$DefaultLintLimit = 100

(*
Number of characters per line to consider "long" and truncate
*)
$LineTruncationLimit = Infinity

(*
How many lines to include above and below each lint
*)
$EnvironBuffer = 1



$DefaultConfidenceLevel = 0.95

$MaxConfidenceLevel = 1.0

$existsTest = Not @* KeyExistsQ[ConfidenceLevel]



CodeInspectSummarize::usage = "CodeInspectSummarize[code] returns an inspection summary object. \
code can be a string, a file, or a list of bytes."

Options[CodeInspectSummarize] = {
  PerformanceGoal -> "Speed",
  "ConcreteRules" :> $DefaultConcreteRules,
  "AggregateRules" :> $DefaultAggregateRules,
  "AbstractRules" :> $DefaultAbstractRules,
  CharacterEncoding -> "UTF-8",
  "TagExclusions" -> $DefaultTagExclusions,
  "SeverityExclusions" -> $DefaultSeverityExclusions,
  ConfidenceLevel :> $DefaultConfidenceLevel,
  "LintLimit" :> $DefaultLintLimit,
  "TabWidth" -> ("TabWidth" /. Options[CodeConcreteParse])
}


(*

There was a change in Mathematica 11.2 to allow 

foo[lints : {___Lint} : Automatic] := lints
foo[]  returns Automatic

Related bugs: 338218
*)

lintsInPat = If[$VersionNumber >= 11.2, {___InspectionObject}, _]

CodeInspectSummarize[File[file_String], lintsIn:lintsInPat:Automatic, OptionsPattern[]] :=
Catch[
 Module[{lints, full, lines, tagExclusions, severityExclusions,
  lintedLines, confidence, lintLimit, performanceGoal, concreteRules,
  aggregateRules, abstractRules, bytes, str, tabWidth},

 lints = lintsIn;

 performanceGoal = OptionValue[PerformanceGoal];
 concreteRules = OptionValue["ConcreteRules"];
 aggregateRules = OptionValue["AggregateRules"];
 abstractRules = OptionValue["AbstractRules"];

 (*
  Support None for the various exclusion options
 *)
 tagExclusions = OptionValue["TagExclusions"];
 If[tagExclusions === None,
  tagExclusions = {}
 ];

 severityExclusions = OptionValue["SeverityExclusions"];
 If[severityExclusions === None,
  severityExclusions = {}
 ];

 confidence = OptionValue[ConfidenceLevel];

 lintLimit = OptionValue["LintLimit"];

 tabWidth = OptionValue["TabWidth"];

  full = FindFile[file];
  If[FailureQ[full],
    Throw[Failure["FindFileFailed", <|"FileName"->file|>]]
  ];

   If[FileByteCount[full] == 0,
   Throw[Failure["EmptyFile", <|"FileName"->full|>]]
   ];

  If[lints === Automatic,
    lints = CodeInspect[File[full],
      PerformanceGoal -> performanceGoal,
      "ConcreteRules" -> concreteRules,
      "AggregateRules" -> aggregateRules,
      "AbstractRules" -> abstractRules,
      "TabWidth" -> tabWidth
    ];
  ];

  (*
  Was:
  bytes = Import[full, "Byte"];

  but this is slow
  *)
  bytes = Normal[ReadByteArray[full]] /. EndOfFile -> {};

   str = SafeString[bytes];

   lines = StringSplit[str, {"\r\n", "\n", "\r"}, All];

   lines = replaceTabs[#, 1, "!", tabWidth]& /@ lines;

  lintedLines = lintLinesReport[lines, lints, tagExclusions, severityExclusions, confidence, lintLimit];

  If[lintedLines == {},
    lintedLines = {
      InspectedLineObject[{
        Column[{
          Text["Settings:"],
          ConfidenceLevel -> confidence,
          "LintLimit" -> lintLimit,
          "TagExclusions" -> tagExclusions,
          "SeverityExclusions" -> severityExclusions
        }]
      }],
      InspectedLineObject[{Text["No issues."]}]
    }
    ,
    lintedLines = {
      InspectedLineObject[{
        Column[{
          Text["Settings:"],
          ConfidenceLevel -> confidence,
          "LintLimit" -> lintLimit,
          "TagExclusions" -> tagExclusions,
          "SeverityExclusions" -> severityExclusions
        }]
      }]
    } ~Join~ lintedLines
  ];

  InspectedFileObject[full, lintedLines]
]]


(*
Allow lints themselves to be summarized

Since we have an explicit lint that we want to summarize, then make sure that "TagExclusions" and
ConfidenceLevel do not interfere with summarizing
*)
CodeInspectSummarize[lint:InspectionObject[_, _, _, KeyValuePattern["File" -> _]], OptionsPattern[]] :=
  Module[{file},

    file = lint[[4, Key["File"]]];

    CodeInspectSummarize[File[file], {lint}, "SeverityExclusions" -> {}, "TagExclusions" -> {}, ConfidenceLevel -> 0.0]
  ]



CodeInspectSummarize[string_String, lintsIn:lintsInPat:Automatic, OptionsPattern[]] :=
Catch[
 Module[{lints, lines, tagExclusions, severityExclusions, lintedLines,
  confidence, lintLimit, performanceGoal, concreteRules, aggregateRules, abstractRules, tabWidth},

 lints = lintsIn;

 performanceGoal = OptionValue[PerformanceGoal];
 concreteRules = OptionValue["ConcreteRules"];
 aggregateRules = OptionValue["AggregateRules"];
 abstractRules = OptionValue["AbstractRules"];

 (*
  Support None for the various exclusion options
 *)
 tagExclusions = OptionValue["TagExclusions"];
 If[tagExclusions === None,
  tagExclusions = {}
 ];

 severityExclusions = OptionValue["SeverityExclusions"];
 If[severityExclusions === None,
  severityExclusions = {}
 ];

 confidence = OptionValue[ConfidenceLevel];

 lintLimit = OptionValue["LintLimit"];

 tabWidth = OptionValue["TabWidth"];


 If[StringLength[string] == 0,
  Throw[Failure["EmptyString", <||>]]
 ];

 If[lints === Automatic,
    lints = CodeInspect[string,
      PerformanceGoal -> performanceGoal,
      "ConcreteRules" -> concreteRules,
      "AggregateRules" -> aggregateRules,
      "AbstractRules" -> abstractRules,
      "TabWidth" -> tabWidth
    ];
  ];

  lines = StringSplit[string, {"\r\n", "\n", "\r"}, All];

  lines = replaceTabs[#, 1, "!", tabWidth]& /@ lines;

  lintedLines = lintLinesReport[lines, lints, tagExclusions, severityExclusions, confidence, lintLimit];

  If[lintedLines == {},
    lintedLines = {
      InspectedLineObject[{
        Column[{
          Text["Settings:"],
          ConfidenceLevel -> confidence,
          "LintLimit" -> lintLimit,
          "TagExclusions" -> tagExclusions,
          "SeverityExclusions" -> severityExclusions
        }]
      }],
      InspectedLineObject[{Text["No issues."]}]
    }
    ,
    lintedLines = {
      InspectedLineObject[{
        Column[{
          Text["Settings:"],
          ConfidenceLevel -> confidence,
          "LintLimit" -> lintLimit,
          "TagExclusions" -> tagExclusions,
          "SeverityExclusions" -> severityExclusions
        }]
      }]
    } ~Join~ lintedLines
  ];

  InspectedStringObject[string, lintedLines]
]]





CodeInspectSummarize[bytes_List, lintsIn:lintsInPat:Automatic, OptionsPattern[]] :=
Catch[
 Module[{lints, lines, tagExclusions, severityExclusions, lintedLines,
  confidence, lintLimit, string, performanceGoal, concreteRules, aggregateRules, abstractRules,
  tabWidth},

 lints = lintsIn;

 performanceGoal = OptionValue[PerformanceGoal];
 concreteRules = OptionValue["ConcreteRules"];
 aggregateRules = OptionValue["AggregateRules"];
 abstractRules = OptionValue["AbstractRules"];

 (*
  Support None for the various exclusion options
 *)
 tagExclusions = OptionValue["TagExclusions"];
 If[tagExclusions === None,
  tagExclusions = {}
 ];

 severityExclusions = OptionValue["SeverityExclusions"];
 If[severityExclusions === None,
  severityExclusions = {}
 ];

 confidence = OptionValue[ConfidenceLevel];

 lintLimit = OptionValue["LintLimit"];

 tabWidth = OptionValue["TabWidth"];

 If[lints === Automatic,
    lints = CodeInspect[bytes,
      PerformanceGoal -> performanceGoal,
      "ConcreteRules" -> concreteRules,
      "AggregateRules" -> aggregateRules,
      "AbstractRules" -> abstractRules,
      "TabWidth" -> tabWidth
    ];
  ];

  string = SafeString[bytes];

  lines = StringSplit[string, {"\r\n", "\n", "\r"}, All];

  lines = replaceTabs[#, 1, "!", tabWidth]& /@ lines;

  lintedLines = lintLinesReport[lines, lints, tagExclusions, severityExclusions, confidence, lintLimit];

  If[lintedLines == {},
    lintedLines = {
      InspectedLineObject[{
        Column[{
          Text["Settings:"],
          ConfidenceLevel -> confidence,
          "LintLimit" -> lintLimit,
          "TagExclusions" -> tagExclusions,
          "SeverityExclusions" -> severityExclusions
        }]
      }],
      InspectedLineObject[{Text["No issues."]}]
    }
    ,
    lintedLines = {
      InspectedLineObject[{
        Column[{
          Text["Settings:"],
          ConfidenceLevel -> confidence,
          "LintLimit" -> lintLimit,
          "TagExclusions" -> tagExclusions,
          "SeverityExclusions" -> severityExclusions
        }]
      }]
    } ~Join~ lintedLines
  ];

  InspectedBytesObject[bytes, lintedLines]
]]



InspectionObject::sourceless = "There are InspectionObjects without Source data. This can happen when some abstract syntax is inspected. \
These InspectionObjects cannot be reported. `1`"

InspectedLineObject::truncation = "Truncation limit reached. Inspected line may not display properly."


(*
Return a list of LintedLines
*)
lintLinesReport[linesIn:{___String}, lintsIn:{___InspectionObject}, tagExclusions_List, severityExclusions_List, confidence_, lintLimit_] :=
Catch[
Module[{lints, lines, sources, warningsLines,
  linesToModify, maxLineNumberLength, lintsPerColumn, sourceLessLints, toRemove, startingPoint, startingPointIndex, elidedLines,
  additionalSources, shadowing, confidenceTest, badLints, truncated, environLines, environLinesTentative},
  
  lints = lintsIn;
  If[$Debug,
    Print["lints: ", lints];
  ];

  (*
  in the course of abstracting syntax, Source information may be lost
  Certain Lints may not have Source information attached
  That is fine, but those Lints cannot be reported
  *)
  sourceLessLints = Cases[lints, InspectionObject[_, _, _, data_ /; !MemberQ[Keys[data], Source]]];

  (*
  If[!empty[sourceLessLints],
    Message[Lint::sourceless, sourceLessLints]
  ];
  *)
  
  lints = Complement[lints, sourceLessLints];
  If[$Debug,
    Print["lints: ", lints];
  ];

  If[empty[lints],
    Throw[{}]
  ];

  (*
  Add a fake line.

  Syntax errors may continue to the end of the file (EOF), and the source location of EOF is {lastLine+1, 0}.
  i.e., it is after all content in the file.

  We want to hash the fake line that is added at the end.
  *)
  lines = linesIn;
  lines = Append[lines, ""];

  If[AnyTrue[lines, (StringLength[#] > $LineTruncationLimit)&],
    truncated = True;
  ];

  lines = StringTake[#, UpTo[$LineTruncationLimit]]& /@ lines;

  If[!empty[tagExclusions],
    lints = DeleteCases[lints, InspectionObject[Alternatives @@ tagExclusions, _, _, _]];
    If[$Debug,
      Print["lints: ", lints];
    ];
  ];

  If[empty[lints],
    Throw[{}]
  ];

  If[!empty[severityExclusions],
    lints = DeleteCases[lints, InspectionObject[_, _, Alternatives @@ severityExclusions, _]];
    If[$Debug,
      Print["lints: ", lints];
    ];
  ];

  If[empty[lints],
    Throw[{}]
  ];


  badLints = Cases[lints, InspectionObject[_, _, _, data_?$existsTest]];
  If[!empty[badLints],
    Message[InspectionObject::confidence, badLints]
  ];

  confidenceTest = GreaterEqualThan[confidence];
  lints = Cases[lints, InspectionObject[_, _, _, KeyValuePattern[ConfidenceLevel -> c_?confidenceTest]]];

  confidenceTest = LessEqualThan[$MaxConfidenceLevel];
  lints = Cases[lints, InspectionObject[_, _, _, KeyValuePattern[ConfidenceLevel -> c_?confidenceTest]]];


  (*

  Disable shadow filtering for now

  Below is quadratic time

  (*
  If a Fatal lint and an Error lint both have the same Source, then only keep the Fatal lint
  *)
  shadowing = Select[lints, Function[lint, AnyTrue[lints, shadows[lint, #]&]]];

  If[$Debug,
    Print["shadowing: ", shadowing];
  ];

  lints = Complement[lints, shadowing];
  If[$Debug,
    Print["lints: ", lints];
  ];
  *)



  If[empty[lints],
    Throw[{}]
  ];
  
  (*
  Make sure to sort lints before taking

  Sort by severity, then sort by Source

  severityToInteger maps "Remark" -> 1 and "Fatal" -> 4, so make sure to negate that
  *)
  lints = SortBy[lints, {-severityToInteger[#[[3]]]&, #[[4, Key[Source]]]&}];

  lints = Take[lints, UpTo[lintLimit]];

  (*
  These are the lints we will be working with
  *)

  If[truncated,
    Message[InspectedLineObject::truncation]
  ];

   sources = Cases[lints, InspectionObject[_, _, _, KeyValuePattern[Source -> src_]] :> src];

   additionalSources = Join @@ Cases[lints, InspectionObject[_, _, _, KeyValuePattern["AdditionalSources" -> srcs_]] :> srcs];

   sources = sources ~Join~ additionalSources;

    (*
    sources = DeleteCases[sources, {{line1_, _}, {_, _}} /; MemberQ[Keys[lineNumberExclusions], line1]];
    *)

    If[empty[sources],
      Throw[{}]
    ];

   warningsLines = sources[[All, All, 1]];

   If[$Debug,
    Print["warningsLines: ", warningsLines];
   ];

   environLinesTentative = Clip[(# + {-$EnvironBuffer, $EnvironBuffer}), {1, Length[lines]}]& /@ warningsLines;
   environLinesTentative = Range @@@ environLinesTentative;

   elidedLines = {};

   linesToModify = Range @@@ warningsLines;

   environLines = MapThread[Complement, {environLinesTentative, linesToModify}];

   linesToModify = MapThread[Union, {linesToModify, environLines}];

   If[$Debug,
    Print["linesToModify before: ", linesToModify];
   ];

   linesToModify = (
      If[Length[#] > $LintedLineLimit,
        toRemove = Length[#] - $LintedLineLimit;
        startingPointIndex = Floor[Length[#]/2] - Floor[toRemove/2] + 1;
        startingPoint = #[[startingPointIndex]];
        AppendTo[elidedLines, startingPoint];
        If[toRemove == 1,
          (* if only removing 1 line, then that single line will be changed to display as "...", so do not need to remove anything *)
          #
          ,
          Drop[#, (startingPointIndex+1);;(startingPointIndex+toRemove-1)]]
        ,
        #
      ])& /@ linesToModify;

   linesToModify = Union[Flatten[linesToModify]];
   environLines = Union[Flatten[environLines]];

   If[$Debug,
    Print["linesToModify after: ", linesToModify];
    Print["elidedLines: ", elidedLines];
    Print["environLines: ", environLines];
   ];

   maxLineNumberLength = Max[IntegerLength /@ linesToModify];

   Table[

      If[!MemberQ[elidedLines, i],
        If[TrueQ[$Underlight],
          With[
            {lintsPerColumn = createLintsPerColumn[lines[[i]], lints, i, "EndOfFile" -> (i == Length[lines])]}
            ,
            {lineSource = lines[[i]],
              lineNumber = i,
              lineList = ListifyLine[lines[[i]],
                lintsPerColumn, "EndOfFile" -> (i == Length[lines])],
              lints = Union[Flatten[Values[lintsPerColumn]]],
              environ = MemberQ[environLines, i]
            }
            ,
            InspectedLineObject[lineSource, lineNumber, lineList, lints, "MaxLineNumberLength" -> maxLineNumberLength, "Environ" -> environ]
          ]
          ,
          (* else *)
          With[
            {lintsPerColumn = createLintsPerColumn[lines[[i]], lints, i, "EndOfFile" -> (i == Length[lines])]}
            ,
            {lineSource = lines[[i]],
              lineNumber = i,
              lineList = ListifyLine[lines[[i]],
                lintsPerColumn, "EndOfFile" -> (i == Length[lines])],
              underlineList = createUnderlineList[lines[[i]], i, lintsPerColumn, "EndOfFile" -> (i == Length[lines])],
              lints = Union[Flatten[Values[lintsPerColumn]]],
              environ = MemberQ[environLines, i]
            }
            ,
            InspectedLineObject[lineSource, lineNumber, { lineList, underlineList }, lints, "MaxLineNumberLength" -> maxLineNumberLength, "Environ" -> environ]
          ]
        ]
        ,
        (* elided *)
        InspectedLineObject["", i, {}, {}, "MaxLineNumberLength" -> maxLineNumberLength, "Elided" -> True, "Environ" -> environ]
      ]
    ,
    {i, linesToModify}
    ]
]]





Options[createUnderlineList] = {
  (*
  Is this line the EndOfFile line?
  *)
  "EndOfFile" -> False
}

createUnderlineList[lineIn_String, lineNumber_Integer, lintsPerColumnIn_Association, opts:OptionsPattern[]] :=
Catch[
 Module[{under, lintsPerColumn, endOfFile, lineIsEmpty, startChar, endChar, startMarker, endMarker, markupPerColumn, line},

  line = lineIn;

  lineIsEmpty = (line == "");

  lintsPerColumn = lintsPerColumnIn;

  If[$Debug,
    Print["lintsPerColumn: ", lintsPerColumn];
  ];

  endOfFile = OptionValue["EndOfFile"];

  markupPerColumn = KeyValueMap[
                      Function[{column, lints},
                        column -> LintMarkup[
                          If[isFirstError[lints, lineNumber, column], LintErrorIndicatorCharacter, LintErrorContinuationIndicatorCharacter],
                          FontWeight->Bold, FontSize->Larger, FontColor->severityColor[lints]]
                      ]
                      ,
                      lintsPerColumn
                    ];
  markupPerColumn = Association[markupPerColumn];

  If[$Debug,
    Print["markupPerColumn: ", markupPerColumn];
  ];

  If[KeyExistsQ[lintsPerColumn, 0],
    startChar = lintsPerColumn[0];

    If[$Debug,
      Print["startChar: ", startChar];
    ];

    (*
   Mark hitting EOF with \[FilledSquare]
   *)
    startMarker = If[endOfFile, LintEOFCharacter, LintContinuationCharacter];
    AssociateTo[markupPerColumn, 0 -> LintMarkup[startMarker, FontWeight->Bold, FontSize->Larger, FontColor->severityColor[startChar]]];
  ];

  (*
  If the line is empty and already added a start continuation, then don't add an end continuation

  This ensures a single \[Continuation] on blank lines
  *)
  Which[
    KeyExistsQ[lintsPerColumn, StringLength[line]+1] && !(lineIsEmpty && KeyExistsQ[lintsPerColumn, 0]),
      endChar = lintsPerColumn[StringLength[line]+1];

      If[$Debug,
        Print["endChar: ", endChar];
      ];

      endMarker = LintContinuationCharacter;
      AssociateTo[markupPerColumn, StringLength[line]+1 -> LintMarkup[endMarker, FontWeight->Bold, FontSize->Larger, FontColor->severityColor[endChar]]];
    ,
    True,
      KeyDropFrom[markupPerColumn, StringLength[line]+1]
  ];

  If[$Debug,
    Print["markupPerColumn: ", markupPerColumn];
  ];

  under = Table[LintSpaceIndicatorCharacter, {StringLength[line]}];
  
  under = Join[{" "}, under, {" "}];

  markupPerColumn = KeyMap[#+1&, markupPerColumn];

  markupPerColumn = Normal[markupPerColumn];

  under = ReplacePart[under, markupPerColumn];

  under
  ]
]


Options[createLintsPerColumn] = {
  "EndOfFile" -> False
}

(*
return an association col -> lints
possibly also 0 -> lints and len+1 -> lints
*)
createLintsPerColumn[line_String, lints_List, lineNumber_Integer, OptionsPattern[]] :=
Module[{perColumn, endOfFile},

  If[$Debug,
    Print["createLintsPerColumn: lineNumber: ", lineNumber];
  ];

  endOfFile = OptionValue["EndOfFile"];

  (*
  setup perColumn
  *)
  perColumn = Map[
    Module[{lint, data, srcs, start, end},
    lint = #;
    data = #[[4]];
    srcs = { data[Source] } ~Join~ Lookup[data, "AdditionalSources", {}];
    (
    Function[src,
    Switch[src,

      (* hitting EOF *)
      {{lineNumber, 0}, {lineNumber, 0}} /; endOfFile,
      Association[0 -> lint]
      ,

      (* staying within same line *)
      {{lineNumber, _}, {lineNumber, _}},
      start = src[[1, 2]];
      Which[
        start > $LineTruncationLimit,
          Association[]
        ,
        src[[2, 2]] > $LineTruncationLimit,
          end = $LineTruncationLimit;
          Association[Table[i -> lint, {i, start, end}]]
        ,
        True,
          end = Min[src[[2, 2]], $LineTruncationLimit];
          Association[dropLastButLeaveAtleastOne[Table[i -> lint, {i, start, end}]]]
      ]
      ,

      (* start on this line, but extends into next lines *)
      {{lineNumber, _}, _},
      Association[Table[i -> lint, {i, src[[1, 2]], StringLength[line]}], StringLength[line]+1 -> lint]
      ,

      (* extend from previous lines, and end on this line *)
      {_, {lineNumber, _}},
      Which[
        src[[2, 2]] > $LineTruncationLimit,
          end = $LineTruncationLimit;
          Association[0 -> lint, Table[i -> lint, {i, 1, end}]]
        ,
        True,
          end = Min[src[[2, 2]], $LineTruncationLimit];
          Association[0 -> lint, dropLastButLeaveAtleastOne[Table[i -> lint, {i, 1, end}]]]
      ]
      ,

      (* extend from previous lines, and also extend into next lines  *)
      {{lineNumber1_, _}, {lineNumber2_, _}} /; (lineNumber1 < lineNumber < lineNumber2),
      Association[0 -> lint, Table[i -> lint, {i, 1, StringLength[line]}], StringLength[line]+1 -> lint]
      ,

      (* nothing to do on this line *)
      _,
      <||>
    ]] /@ srcs)]&
    ,
    lints
  ];
  perColumn = Merge[Flatten[perColumn], Identity];

  perColumn
]



dropLastButLeaveAtleastOne[{}] := {}
dropLastButLeaveAtleastOne[{a_}] := {a}
dropLastButLeaveAtleastOne[{most___, a_, b_}] := {most, a}




Options[ListifyLine] = {
  "EndOfFile" -> False
}

(*
lineIn: the line to change
lintsPerColumn: an Association col -> lints

return a list of unchanged characters, LintedCharacters, and " "
pad with " " on either side to allow for \[Continuation] markers and \[Times] markers
*)
ListifyLine[lineIn_String, lintsPerColumnIn_Association, opts:OptionsPattern[]] :=
Module[{line, lintsPerColumn},

  If[$Debug,
    Print["ListifyLine: line: ", lineIn];
  ];

  line = lineIn;

  lintsPerColumn = lintsPerColumnIn;

  (* there may be lints in the gutters, but we do not care here *)
  KeyDropFrom[lintsPerColumn, 0];
  KeyDropFrom[lintsPerColumn, StringLength[line]+1];
  
  line = StringReplace[line, $characterReplacementRules];
  
  line = Characters[line];

  If[TrueQ[$Underlight],
    lintsPerColumn = KeyValueMap[#1 -> LintMarkup[line[[#1]], FontVariations -> {"Underlight" -> severityColor[#2]}]&, lintsPerColumn];
    ,
    lintsPerColumn = KeyValueMap[#1 -> LintMarkup[line[[#1]], FontWeight->Bold, FontColor->severityColor[#2]]&, lintsPerColumn];
  ];

  line = ReplacePart[line, lintsPerColumn];

  line = Join[{" "}, line, {" "}];

  line
]



End[]

EndPackage[]
