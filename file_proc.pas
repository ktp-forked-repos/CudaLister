unit file_proc;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LazUTF8Classes;

function IsFileContentText(const fn: string; BufSizeKb: DWORD;
  DetectOEM: Boolean; out IsOEM: Boolean): Boolean;

implementation

type
  TFreqTable = array[$80 .. $FF] of Integer;

function IsFileContentText(const fn: string; BufSizeKb: DWORD;
  DetectOEM: Boolean; out IsOEM: Boolean): Boolean;
var
  Buffer: PAnsiChar;
  BufSize, BytesRead, i: DWORD;
  n: Integer;
  Table: TFreqTable;
  TableSize: Integer;
  Str: TFileStreamUTF8;
  SSign: string;
begin
  Result:= False;
  IsOEM:= False;
  Str:= nil;
  Buffer:= nil;

  if BufSizeKb<=0 then Exit;
  BufSize:= BufSizeKb*1024;

  //Init freq table
  TableSize:= 0;
  FillChar(Table, SizeOf(Table), 0);

  try
    GetMem(Buffer, BufSize);
    FillChar(Buffer^, BufSize, 0);

    try
      Str:= TFileStreamUTF8.Create(fn, fmOpenRead or fmShareDenyNone);
    except
      Result:= false;
      Exit
    end;

    Str.Position:= 0;
    if Str.Size<=2 then
      begin Result:= true; Exit end;

    BytesRead:= Str.Read(Buffer^, BufSize);
    if BytesRead > 0 then
      begin
        //Test UTF16 signature
        SetString(SSign, Buffer, 2);
        if (SSign=#$ff#$fe) or (SSign=#$fe#$ff) then Exit(True);

        Result:= True;
        for i:= 0 to BytesRead - 1 do
        begin
          n:= Ord(Buffer[i]);

          //If control chars present, then non-text
          if (n < 32) and (n <> 09) and (n <> 13) and (n <> 10) then
            begin Result:= False; Break end;

          //Calculate freq table
          if DetectOEM then
            if (n >= Low(Table)) and (n <= High(Table)) then
            begin
              Inc(TableSize);
              Inc(Table[n]);
            end;
        end;
      end;

    //Analize table
    if DetectOEM then
      if Result and (TableSize > 0) then
        for i:= Low(Table) to High(Table) do
        begin
          Table[i]:= Table[i] * 100 div TableSize;
          if ((i >= $B0) and (i <= $DF)) or (i = $FF) or (i = $A9) then
            if Table[i] >= 18 then
              begin IsOEM:= True; Break end;
        end;

  finally
    if Assigned(Buffer) then
      FreeMem(Buffer);
    if Assigned(Str) then
      FreeAndNil(Str);
  end;
end;

end.

