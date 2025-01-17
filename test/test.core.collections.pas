/// regression tests for most mormot.core.collections unit
// - this unit is a part of the Open Source Synopse mORMot framework 2,
// licensed under a MPL/GPL/LGPL three license - see LICENSE.md
unit test.core.collections;

interface

{$I ..\src\mormot.defines.inc}

{$ifdef HASGENERICS} // do-nothing unit on oldest compilers (e.g. < Delphi 2010)

uses
  sysutils,
  classes,
  mormot.core.base,
  mormot.core.os,
  mormot.core.text,
  mormot.core.buffers,
  mormot.core.unicode,
  mormot.core.rtti,
  mormot.core.variants,
  mormot.core.json,
  mormot.core.data,
  mormot.core.collections,
  mormot.core.perf,
  mormot.core.test;


type
  /// regression tests for mormot.core.collections features
  TTestCoreCollections = class(TSynTestCase)
  protected
    procedure TestOne<T>;
  published
    procedure _IList;
  end;

implementation


{ TTestCoreCollections }

{$I-}

{$define TESTHASH128}

{$ifndef TESTHASH128}
  {$define USEEQUALOP}
{$endif TESTHASH128}

{$ifndef FPC}
  // Delphi is sometimes just buggy: equal operator is not allowed in TestOne<T>
  {$undef USEEQUALOP}
{$endif FPC}

procedure TTestCoreCollections.TestOne<T>;
const
  MAX = 100000;
  ONLYLOG = true; // set to FALSE for verbose benchmarking console output
var
  li: IList<T>;
  cop: TArray<T>;
  i, j: T;
  n: integer;
  timer, all: TPrecisionTimer;
  v: PVariantArray;
  {$ifndef USEEQUALOP}
  p0, p1: ^T;
  {$endif FPC}
  da: PDynArray;
  name: RawUtf8;
begin
  SetLength(cop, MAX);
  all.Start;
  // circumvent FPC x86_64/aarch64 internal error 2010021502 :(
  // - root cause seems to be that T is coming through TestOne<T> generic method
  // - direct specialization like Collections.NewList<integer> works fine
  {$ifdef FPC_64}
  li := TSynListSpecialized<T>.Create;
  {$else}
  li := Collections.NewList<T>;
  {$endif FPC_64}
  da := li.Data;
  name := da^.Info.ArrayRtti.Name;
  Check(name <> '');
  for i in li do
  begin
   TestFailed('void list');
    {%H-}cop[0] := i;  // the compiler needs to use i somewhere
  end;
  timer.Start;
  for n := 0 to MAX - 1 do
    da^.ItemRandom(@cop[n]);
  NotifyTestSpeed('random % ', [name], MAX, 0, @timer, ONLYLOG);
  timer.Start;
  li.Capacity := MAX;
  for n := 0 to MAX - 1 do
    Check(li.Add(cop[n]) = n);
  NotifyTestSpeed('add %    ',  [name], MAX, 0, @timer, ONLYLOG);
  CheckEqual(li.Count, MAX);
  timer.Start;
  for n := 0 to MAX - 1 do
  begin
    {$ifdef USEEQUALOP}
    Check(li[n] = cop[n]);
    {$else}
    i := li[n];
    Check(da.ItemCompare(@i, @cop[n]) = 0);
    {$endif USEEQUALOP}
  end;
  NotifyTestSpeed('getitem %', [name], MAX, 0, @timer, ONLYLOG);
  timer.Start;
  n := 0;
  for i in li do
  begin
    {$ifdef USEEQUALOP}
    Check(i = cop[n]);
    {$else}
    Check(da.ItemCompare(@i, @cop[n]) = 0);
    {$endif USEEQUALOP}
    inc(n);
  end;
  NotifyTestSpeed('in %     ', [name], MAX, 0, @timer, ONLYLOG);
  Check(n = MAX);
  NotifyTestSpeed(' IList<%>', [name], MAX * 4, 0, @all, {onlylog=}false);
  timer.Start; // Sort is excluded of main "all" timer since is misleading
  li.Sort;
  NotifyTestSpeed('sort %   ', [name], MAX, 0, @timer, ONLYLOG);
  if TypeInfo(T) = TypeInfo(variant) then
  begin
    v := li.First;
    for n := 0 to MAX - 2 do
      Check(VariantCompare(v[n], v[n+1]) <= 0);
    exit; // Sort+Find do not match with variants due to duplicates
  end;
  {$ifdef USEEQUALOP}
  for n := 0 to MAX - 2 do
    Check(li[n] <= li[n+1]); // internal error on Delphi :(
  {$else}
  p1 := li.First;
  p0 := p1;
  inc(p1);
  for n := 0 to MAX - 2 do
  begin
    Check(da.ItemCompare(p0, p1) <= 0); // manual validate sort
    inc(p0);
    inc(p1);
  end;
  {$endif USEEQUALOP}
  timer.Start;
  for n := 0 to MAX - 1 do
  {$ifdef USEEQUALOP}
    Check(li[li.Find(cop[n])] = cop[n], 'sorted find');
  {$else}
  begin
    i := li[li.Find(cop[n])];
    Check(da.ItemCompare(@i, @cop[n]) = 0, 'sorted find');
  end;
  {$endif USEEQUALOP}
  NotifyTestSpeed('find %   ', [name], MAX, 0, @timer, ONLYLOG);
  Check(li.Count = MAX);
  li.Clear;
  Check(li.Count = 0);
end;

procedure TTestCoreCollections._IList;
const
  MAX = 1000; // not too big since here we validate also brute force searches
var
  i: integer;
  pi: PInteger;
  li: IList<integer>;
  u: RawUtf8;
  pu: PRawUtf8;
  lu: IList<RawUtf8>;
  lh: IList<THash128>;
  h: THash128;
begin
  // manual IList<integer> validation
  li := Collections.NewList<integer>;
  for i in li do
    Check(i < 0);
  li.Capacity := MAX + 1;
  Check(li.Count = 0);
  for i in li do
    Check(i < 0);
  for i in li.Range(-5) do
    Check(i < 0);
  for i := 0 to MAX do          // populate with some data
    Check(li.Add(i) = i);
  for i := 0 to li.Count - 1 do // regular Items[] access
    Check(li[i] = i);
  for i in li do                // use an enumerator - safe and clean
    Check(cardinal(i) <= MAX);
  for i in li.Range(-5) do      // use an enumerator for the last 5 items
    Check(i > MAX - 5);
  for i in li do
    Check(li.IndexOf(i) = i);   // O(n) brute force search
  for i in li do
    Check(li.Find(i) = i);      // O(n) brute force search
  pi := li.First;
  for i := 0 to li.Count - 1 do // fastest method
  begin
    Check(pi^ = i);
    inc(pi);
  end;
  li := Collections.NewList<integer>([loCreateUniqueIndex]);
  li.Capacity := MAX + 1;
  for i := 0 to MAX do          // populate with some data
    Check(li.Add(i) = i);
  for i in li do                // use an enumerator - safe and clean
    Check(cardinal(i) <= MAX);
  for i in li do
    Check(li.IndexOf(i) = i);   // O(n) brute force search
  for i in li do
    Check(li.Find(i) = i);      // O(1) hash table search
  // manual IList<RawUtf8> validation
  lu := Collections.NewList<RawUtf8>;
  for u in lu do
    Check(u = #0);
  lu.Capacity := MAX + 1;
  Check(lu.Count = 0);
  for u in lu do
    Check(u = #0);
  for u in lu.Range(-5) do
    Check(u = #0);
  for i := 0 to MAX do          // populate with some data
    Check(lu.Add(UInt32ToUtf8(i)) = i);
  for i := 0 to lu.Count - 1 do // regular Items[] access
    Check(Utf8ToInteger(lu[i]) = i);
  i := 0;
  for u in lu do                // use an enumerator - safe and clean
  begin
    Check(Utf8ToInteger(u) = i);
    inc(i);
  end;
  for u in lu.Range(-5) do      // use an enumerator for the last 5 items
    Check(Utf8ToInteger(u) > MAX - 5);
  for u in lu do
    Check(lu.IndexOf(u) = Utf8ToInteger(u));   // O(n) brute force search
  for u in lu do
    Check(lu.Find(u) = Utf8ToInteger(u));      // O(n) brute force search
  pu := lu.First;
  for i := 0 to lu.Count - 1 do // fastest method
  begin
    Check(Utf8ToInteger(pu^) = i);
    inc(pu);
  end;
  lu := Collections.NewList<RawUtf8>([loCreateUniqueIndex]);
  lu.Capacity := MAX + 1;
  for i := 0 to MAX do          // populate with some data
    Check(lu.Add(UInt32ToUtf8(i)) = i);
  i := 0;
  for u in lu do                // use an enumerator - safe and clean
  begin
    Check(Utf8ToInteger(u) = i);
    Check(lu.IndexOf(u) = i);   // O(n) brute force search
    Check(lu.Find(u) = i);      // O(1) hash table search
    inc(i);
  end;
  // minimal THash128 compilation check
  lh := Collections.NewList<THash128>;
  FillZero(h);
  lh.Add(h);
  lh.Sort;
  lh := nil;
  // validate and benchmark all main types using a generic sub method
  TestOne<byte>();
  TestOne<word>();
  TestOne<integer>();
  TestOne<cardinal>();
  TestOne<Int64>();
  TestOne<QWord>();
  TestOne<Single>();
  TestOne<Double>();
  TestOne<TDateTime>();
  TestOne<RawUtf8>();
  {$ifdef MSWINDOWS} // OleString on Windows only -> = UnicodeString on POSIX
  // disabled since SPECIALIZE_WSTRING is not set
  //TestOne<WideString>();
  // note: WideString (BSTR API) is way slower than UnicodeString or RawUtf8
  {$endif MSWINDOWS}
  {$ifdef HASVARUSTRING}
  TestOne<UnicodeString>();
  {$endif HASVARUSTRING}
  TestOne<Variant>();
  {$ifdef TESTHASH128}
  TestOne<THash128>();
  TestOne<TGuid>();
  {$endif TESTHASH128}
end;

{$else}

implementation

{$endif HASGENERICS} // do-nothing unit on oldest compilers


end.

