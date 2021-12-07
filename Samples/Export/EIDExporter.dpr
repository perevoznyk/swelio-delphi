program EIDExporter;

{$APPTYPE CONSOLE}
{$R *.RES}

uses
  SysUtils,
  Classes,
  AnsiStrings,
  SwelioEngine,
  SwelioTypes;

var
  FileName : AnsiString;
  PictureName : AnsiString;
  bCardWait : boolean;
  bInteractive : boolean;
  bSISCard : boolean;
  iWaitTime : integer;
  bListReaders : boolean;
  bPicture : boolean;
  bEID : boolean;
  iReaderNumber : integer;
  bPictureOnly : boolean;
  bCardInserted : boolean;

procedure Error(Msg : string);
begin
  writeln(Msg);
  Halt(1);
end;

function ParseInteger(arg : string) : integer;
var
  code : integer;
  cvarg : string;
begin
  if (Length(arg) > 1) and (UpperCase(Copy(arg, 1, 2)) = '0X') then
    {convert C-style hex to Pascal-style hex}
    cvarg := '$'+copy(arg, 3, length(arg))
  else
    cvarg := arg;

  {val supports decimal and Pascal-style hex}
  val(cvarg, result, code);
  if code <> 0 then
    Error('Expected integer but got '+arg);
end;


procedure ParseCommandLine;
var
  i : integer;
  arg : string;
  command : string;

  procedure RefreshArg;
    {-Allow for optional space between command line option and its argument}
  begin
    if Length(arg) = 0 then begin
      inc(i);
      if i > ParamCount then
        Error('Argument value missing at end of command line');
      arg := ParamStr(i);
    end;
  end;

begin
  {parse command line}
  i := 1;
  while i <= ParamCount do begin
    arg := ParamStr(i);
    if (arg[1] = '/') or (arg[1] = '-') then begin
      {command line option}
      if Length(arg) < 2 then
        Error('Invalid option: '+arg);
      Delete(arg, 1, 1);

      {classify the option}
      command := UpperCase(arg[1]);
      if command = 'F' then begin
        Delete(arg, 1, 1);
        if (i = ParamCount) then
          begin
            FileName := '';
          end
            else
              begin
                RefreshArg;
                if (arg[1] = '/') or (arg[1] = '-') then
                 begin
                   FileName := '';
                   dec(i);
                 end
                  else
                    FileName := AnsiString(arg);
              end;

      end else if command = 'P' then begin
        delete(arg,1,1);
        bPicture := true;
        if (i = ParamCount) then
         begin
           PictureName := '';
         end
           else
             begin
              RefreshArg;
              if (arg[1] = '/') or (arg[1] = '-') then
              begin
                PictureName := '';
                dec(i);
              end
                else
                  begin
                    PictureName := AnsiString(arg);
                  end;
             end;

      end else if command = 'T' then begin
        delete(arg,1,1);
        RefreshArg;
        IWaitTime := ParseInteger(arg);

      end else if command = 'R' then begin
        delete(arg,1,1);
        RefreshArg;
        iReaderNumber := ParseInteger(arg);

      end else if command = 'L' then begin
       // delete (arg,1,1);
        RefreshArg;
        bListReaders := true;

      end else if command = 'W' then begin
       // delete (arg,1,1);
        RefreshArg;
        bCardWait := true;

      end else if command = 'E' then begin
       // delete (arg,1,1);
        RefreshArg;
        bEID := true;

      end else if command = 'I' then begin
        //delete(arg,1,1);
        RefreshArg;
        bInteractive := true;

      end else if command = 'S' then begin
        {include path}
        //Delete(arg, 1, 1);
        RefreshArg;
        bSISCard := true;

      end;
    inc(i);
    end
     else
       inc(i);
  end;
end;

procedure _SaveReadersToCSV(FileName: AnsiString); stdcall;
var
  FS: TFileStream;
  S: AnsiString;
  SL: TStringList;
  i : integer;
  l : integer;
  buf : String;
begin
  if (IsEngineActive) then
  begin
    FS := TFileStream.Create(UnicodeString(FileName), fmCreate);
    try
      SL := TStringList.Create;
      try
        SL.Delimiter := ';';
        for I := 0 to GetReadersCount- 1 do
           begin
             l := GetReaderNameLenW(I);
             SetLength(buf, l);
             GetReaderNameW(I, PChar(buf), l);
             SL.Add(buf);
           end;
        S := AnsiString(SL.CommaText);
      finally
        SL.Free;
      end;
      FS.Write(S[1], length(S));
    finally
      FS.Free;
    end;
  end;
end;

function WaitForCard(WaitTime: integer): boolean;
begin
  Sleep(WaitTime);
  Result := IsCardPresent;
end;

begin
  try
    { TODO -oUser -cConsole Main : Insert code here }
    if (ParamCount = 0) then
      begin
        writeln('Belgian eID data export to CSV');
        writeln('Copyright (C) 2009 - 2021 Serhiy Perevoznyk');
        writeln('Usage: ' + ExtractFileName(ParamStr(0)) + ' -f <file name> [options]');
        writeln('Options:');
        writeln(' -f <file name>      write eID information to specified output file');
        writeln(' -w                  wait for card to be inserted');
        writeln(' -t <seconds>        time to wait (default 60 sec)');
        writeln(' -p [file name]      save picture [to specified output file]');
        writeln(' -l                  save the smart card readers list to the file');
        writeln(' -r <reader number>  use specified smart card reader');
        writeln(' -i                  interactive mode');
        writeln(' -e                  process eID card');
        writeln;

        writeln('Examples:');
        writeln;
        writeln('Wait 30 sec for the eID card to be inserted and save the data to person.csv file');
        writeln(ExtractFileName(ParamStr(0)) + ' -f person.csv -w -t30 -e');

        writeln;
        writeln('Wait for the card to be inserted, save the data to person.csv file and save the photo to picture.jpg file');
        writeln(ExtractFileName(ParamStr(0)) + ' -f person.csv -w -p picture.jpg');

        writeln;
        writeln('Read SIS card in interactive mode and save the data to person.csv file');
        writeln(ExtractFileName(ParamStr(0)) + ' -f person.csv -s -i');
        Halt(1);
      end;

    iReaderNumber := 0;

    ParseCommandLine;

    if Trim(FileName) = '' then
      begin
        writeln('File name must be specified: -f <file name> option is missing');
        halt(1);
      end;

    if ((bSISCard) and (bPicture)) then
     begin
       writeln('There is no picture stored on SIS card. Do not use -p option with -s option');
       halt(1);
     end;

    if (bSISCard and bEID) then
      begin
        writeln('-s and -e parameters can not be combined. Please specify only one card type');
        halt(1);
      end;

     if (not bSISCard) and (not bEID) then
       bEid := true;

     StartEngine;
     if GetReadersCount < 1 then
      begin
        writeln('Card reader not detected');
        halt(1);
      end;

     SelectReader(iReaderNumber);

     if GetReadersCount > 0 then
      begin
         if bListReaders then
           begin
             _SaveReadersToCSV(FileName);
           end
             else
               begin
                 ActivateCardEx(iReaderNumber);

                 if bCardWait then
                   begin
                     if not IsCardPresentEx(iReaderNumber) then
                        begin
                           if (bInteractive) then
                            writeln('Please insert the card into reader');
                           if iWaitTime <= 0 then
                             iWaitTime := 60;
                           bCardInserted := WaitForCard(iWaitTime);
                        end
                         else
                           bCardInserted := true;
                   end
                     else
                       bCardInserted := true;


                  if bCardInserted then
                     begin
                        if (bSISCard) then
                          begin
                               if bInteractive then
                                writeln('SIS card not supported anymore');
                          end
                            else
                              begin
                               if IsEIDCard then
                                begin
                                   if (bPicture and (Trim(PictureName) = '')) then
                                     bPictureOnly := true
                                       else
                                         bPictureOnly := false;

                                    if bPictureOnly then
                                       begin
                                         SavePhotoAsJpegA(PAnsiChar(FileName));
                                       end
                                         else
                                           begin
                                            SavePersonToCSVA(PAnsiChar(FileName));
                                            if (Trim(PictureName) <> '') then
                                              begin
                                                SavePhotoAsJpegA(PAnsiChar(PictureName));
                                              end;
                                           end;
                                end
                                 else
                                   begin
                                     if bInteractive then
                                      writeln('No eID card detected in the card reader');
                                   end;
                              end;
                     end
                       else
                         begin
                           if bInteractive  then
                            writeln('There is no card inserted into reader');
                         end;

               end;
      end
        else
          begin
            if bInteractive then
              writeln('There is no any smart card reader detected');
          end;
     StopEngine();
  except
    on E:Exception do
     begin
       if bInteractive then
         Writeln(E.Classname, ': ', E.Message);
     end;
  end;
end.
