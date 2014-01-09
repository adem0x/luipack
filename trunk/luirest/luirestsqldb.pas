unit LuiRESTSqldb;

{$mode objfpc}{$H+}
{$define USE_SQLITE3_SLIM}

interface

uses
  Classes, SysUtils, sqldb, db, LuiRESTServer, HTTPDefs, fphttp, fpjson,
  {$ifdef USE_SQLITE3_SLIM}
  sqlite3slimconn
  {$else}
  sqlite3conn
  {$endif}
  ;

type

  { TSqldbJSONResource }

  TSqldbJSONResource = class(TRESTResource)
  private
    FConditionsSQL: String;
    FConnection: TSQLConnection;
    FOutputFields: String;
    FPrimaryKey: String;
    FPrimaryKeyParam: String;
    FSelectSQL: String;
    FInputFieldsData: TJSONArray;
    FIsCollection: Boolean;
    FPreserveCase: Boolean;
    FPutAsPatch: Boolean;
    FReadOnly: Boolean;
    class var FDefaultConnection: TSQLConnection;
    class procedure SetDefaultConnection(Value: TSQLConnection); static;
    procedure SetInputFields(const AValue: String);
  protected
    function GetQuery(AOwner: TComponent): TSQLQuery;
    function GetResourceIdentifierSQL: String;
    function GetNewResourceId(Query: TSQLQuery): String; virtual;
    procedure SetQueryData(Query: TSQLQuery; Obj1, Obj2: TJSONObject; DoPatch: Boolean = False);
  public
    destructor Destroy; override;
    procedure AfterConstruction; override;
    procedure HandleGet(ARequest: TRequest; AResponse: TResponse); override;
    procedure HandleDelete(ARequest: TRequest; AResponse: TResponse); override;
    procedure HandlePost(ARequest: TRequest; AResponse: TResponse); override;
    procedure HandlePut(ARequest: TRequest; AResponse: TResponse); override;
    property ConditionsSQL: String read FConditionsSQL write FConditionsSQL;
    property Connection: TSQLConnection read FConnection write FConnection;
    class property DefaultConnection: TSQLConnection read FDefaultConnection write SetDefaultConnection;
    property IsCollection: Boolean read FIsCollection write FIsCollection;
    property OutputFields: String read FOutputFields write FOutputFields;
    property PreserveCase: Boolean read FPreserveCase write FPreserveCase;
    property PrimaryKey: String read FPrimaryKey write FPrimaryKey;
    property PrimaryKeyParam: String read FPrimaryKeyParam write FPrimaryKeyParam;
    //todo: remove when Patch support is added
    property PutAsPatch: Boolean read FPutAsPatch write FPutAsPatch;
    property ReadOnly: Boolean read FReadOnly write FReadOnly;
    property SelectSQL: String read FSelectSQL write FSelectSQL;
    property InputFields: String write SetInputFields;
  end;

procedure JSONDataToParams(JSONObj: TJSONObject; Params: TParams);

implementation

uses
  LuiJSONUtils;

procedure JSONDataToParams(JSONObj: TJSONObject; Params: TParams);
var
  i: Integer;
  Param: TParam;
  PropName: String;
begin
  Params.Clear;
  for i := 0 to JSONObj.Count -1 do
  begin
    PropName := JSONObj.Names[i];
    Param := Params.FindParam(PropName);
    if Param = nil then
    begin
      Param := TParam.Create(Params, ptInput);
      Param.Name := PropName;
    end;
    Param.Value := JSONObj.Items[i].Value;
  end;
end;

function GetFieldName(FieldsData: TJSONArray; FieldIndex: Integer; out DBFieldName: String): String;
var
  FieldData: TJSONData;
begin
  FieldData := FieldsData.Items[FieldIndex];
  if FieldData.JSONType = jtString then
  begin
    Result := FieldData.AsString;
    DBFieldName := Result;
  end
  else if FieldData.JSONType = jtObject then
  begin
    Result := TJSONObject(FieldData).Get('name', '');
    DBFieldName := TJSONObject(FieldData).Get('mapping', Result);
  end
  else
    Result := '';
end;


procedure TSqldbJSONResource.SetQueryData(Query: TSQLQuery; Obj1, Obj2: TJSONObject;
  DoPatch: Boolean);
var
  i: Integer;
  FieldName, DBFieldName: String;
  PropData: TJSONData;
  Field: TField;
begin
  if FInputFieldsData <> nil then
  begin
    for i := 0 to FInputFieldsData.Count - 1 do
    begin
      FieldName := GetFieldName(FInputFieldsData, i, DBFieldName);
      Field := Query.FieldByName(DBFieldName);
      PropData := Obj1.Find(FieldName);
      if PropData = nil then
        PropData := Obj2.Find(FieldName);
      if PropData <> nil then
        Field.Value := PropData.Value
      else
      begin
        if not DoPatch then
          Field.Value := Null;
      end;
    end;
  end
  else
  begin
    // no specific columns set
    for i := 0 to Query.Fields.Count -1 do
    begin
      Field := Query.Fields[i];
      FieldName := LowerCase(Field.FieldName);
      if SameText(FieldName, FPrimaryKey) then
        continue;
      PropData := Obj1.Find(FieldName);
      if PropData = nil then
        PropData := Obj2.Find(FieldName);
      if PropData <> nil then
        Field.Value := PropData.Value
      else
      begin
        if not DoPatch then
          Field.Value := Null;
      end;
    end;
  end;
end;

{ TSqldbJSONResource }

procedure TSqldbJSONResource.SetInputFields(const AValue: String);
begin
  FreeAndNil(FInputFieldsData);
  TryStrToJSON(AValue, FInputFieldsData);
end;

class procedure TSqldbJSONResource.SetDefaultConnection(Value: TSQLConnection);
begin
  if (FDefaultConnection <> nil) and (Value <> nil) then
    raise Exception.Create('Default connection already set');
  FDefaultConnection := Value;
end;

function TSqldbJSONResource.GetQuery(AOwner: TComponent): TSQLQuery;
begin
  Result := TSQLQuery.Create(AOwner);
  Result.DataBase := FConnection;
end;

function TSqldbJSONResource.GetResourceIdentifierSQL: String;
begin
  if FConditionsSQL <> '' then
    Result := FConditionsSQL
  else if (FPrimaryKeyParam <> '') and (FPrimaryKey <> '') then
    Result := Format('where %s = :%s', [FPrimaryKey, FPrimaryKeyParam])
  else
    raise Exception.Create('Unable to resolve resource identifier SQL query');
end;

function TSqldbJSONResource.GetNewResourceId(Query: TSQLQuery): String;
begin
  //found a way to retrieve LastInsertID only for sqlite3
  if (FConnection is TSQLite3Connection) then
    Result := IntToStr(TSQLite3Connection(FConnection).GetInsertID)
  else
    Result := '';
end;

destructor TSqldbJSONResource.Destroy;
begin
  FInputFieldsData.Free;
  inherited Destroy;
end;

procedure TSqldbJSONResource.AfterConstruction;
begin
  inherited AfterConstruction;
  FPrimaryKey := 'Id';
  FConnection := FDefaultConnection;
end;

procedure TSqldbJSONResource.HandleGet(ARequest: TRequest; AResponse: TResponse);
var
  Query: TSQLQuery;
  ResponseData: TJSONData;
  ConvertOptions: TDatasetToJSONOptions;
begin
  Query := TSQLQuery.Create(nil);
  try
    Query.DataBase := FConnection;
    Query.SQL.Add(FSelectSQL);
    if FIsCollection then
      Query.SQL.Add(FConditionsSQL)
    else
      Query.SQL.Add(GetResourceIdentifierSQL);
    JSONDataToParams(URIParams, Query.Params);
    try
      Query.Open;
    except
      on E: Exception do
      begin
        SetResponseStatus(AResponse, 500, 'An exception ocurred opening a query: %s', [E.Message] );
        Exit;
      end;
    end;
    if FIsCollection then
    begin
      ConvertOptions := [djoSetNull];
      if FPreserveCase then
        Include(ConvertOptions, djoPreserveCase);
      ResponseData := TJSONArray.Create;
      try
        DatasetToJSON(Query, TJSONArray(ResponseData), ConvertOptions, FOutputFields);
        AResponse.Contents.Add(ResponseData.AsJSON);
      finally
        ResponseData.Free;
      end;
    end
    else
    begin
      if (Query.RecordCount > 0) then
      begin
        ConvertOptions := [djoSetNull];
        if FPreserveCase then
          Include(ConvertOptions, djoPreserveCase);
        ResponseData := TJSONObject.Create;
        try
          DatasetToJSON(Query, TJSONObject(ResponseData), ConvertOptions, FOutputFields);
          AResponse.Contents.Add(ResponseData.AsJSON);
        finally
          ResponseData.Free;
        end;
      end
      else
      begin
        SetResponseStatus(AResponse, 404, 'Resource "%s" not found', [ARequest.PathInfo]);
      end;
    end;
  finally
    Query.Destroy;
  end;
end;

procedure TSqldbJSONResource.HandleDelete(ARequest: TRequest; AResponse: TResponse);
var
  Query: TSQLQuery;
begin
  if not FIsCollection and not FReadOnly then
  begin
    Query := TSQLQuery.Create(nil);
    try
      Query.DataBase := FConnection;
      Query.SQL.Add(FSelectSQL);
      Query.SQL.Add(GetResourceIdentifierSQL);
      JSONDataToParams(URIParams, Query.Params);
      try
        Query.Open;
      except
        on E: Exception do
        begin
          SetResponseStatus(AResponse, 500, 'An exception ocurred opening a query: %s', [E.Message] );
          Exit;
        end;
      end;
      if not Query.IsEmpty then
      begin
        Query.Delete;
        Query.ApplyUpdates;
        FConnection.Transaction.Commit;
      end;
    finally
      Query.Destroy;
    end;
  end
  else
    inherited HandleDelete(ARequest, AResponse);
end;

procedure TSqldbJSONResource.HandlePost(ARequest: TRequest; AResponse: TResponse);
var
  RequestData: TJSONObject;
  Query: TSQLQuery;
  NewResourcePath, NewResourceId: String;
begin
  if FIsCollection and not FReadOnly then
  begin
    Query := TSQLQuery.Create(nil);
    try
      Query.DataBase := FConnection;
      Query.SQL.Add(FSelectSQL);
      Query.SQL.Add('where 1 <> 1');
      JSONDataToParams(URIParams, Query.Params);
      if TryStrToJSON(ARequest.Content, RequestData) then
      begin
        try
          Query.Open;
          Query.Append;
          SetQueryData(Query, RequestData, URIParams);
          Query.Post;
          Query.ApplyUpdates;
          FConnection.Transaction.CommitRetaining;
        except
          on E: Exception do
          begin
            SetResponseStatus(AResponse, 400, 'Error posting to %s: %s', [ARequest.PathInfo, E.Message]);
            Exit;
          end;
        end;
        RequestData.Free;
      end
      else
      begin
        //todo: improve error handling
        SetResponseStatus(AResponse, 400, 'Error posting to %s', [ARequest.PathInfo]);
        Exit;
      end;
      NewResourceId := GetNewResourceId(Query);
      if NewResourceId <> '' then
      begin
        NewResourcePath := ARequest.PathInfo;
        if NewResourcePath[Length(NewResourcePath)] <> '/' then
          NewResourcePath := NewResourcePath + '/';
        NewResourcePath := NewResourcePath + NewResourceId;
        RedirectRequest(ARequest, AResponse, 'GET', NewResourcePath, False);
      end
      else
        SetResponseStatus(AResponse, 400, '"%s" - Unable to get resource id', [ARequest.PathInfo]);
    finally
      Query.Destroy;
    end;
  end
  else
    inherited HandlePost(ARequest, AResponse);
end;

procedure TSqldbJSONResource.HandlePut(ARequest: TRequest; AResponse: TResponse);
var
  RequestData: TJSONObject;
  ResponseData: TJSONObject;
  Query: TSQLQuery;
  ConvertOptions: TDatasetToJSONOptions;
begin
  if not FIsCollection and not FReadOnly then
  begin
    Query := TSQLQuery.Create(nil);
    try
      Query.DataBase := FConnection;
      Query.SQL.Add(FSelectSQL);
      Query.SQL.Add(GetResourceIdentifierSQL);
      JSONDataToParams(URIParams, Query.Params);
      Query.Open;
      if TryStrToJSON(ARequest.Content, RequestData) then
      try
        Query.Edit;
        SetQueryData(Query, RequestData, URIParams, FPutAsPatch);
        Query.Post;
        Query.ApplyUpdates;
        FConnection.Transaction.CommitRetaining;
      finally
        RequestData.Free;
      end;
      ConvertOptions := [djoSetNull];
      if FPreserveCase then
        Include(ConvertOptions, djoPreserveCase);
      ResponseData := TJSONObject.Create;
      try
        DatasetToJSON(Query, ResponseData, ConvertOptions, FOutputFields);
        AResponse.Contents.Add(ResponseData.AsJSON);
      finally
        ResponseData.Free;
      end;
    finally
      Query.Destroy;
    end;
  end
  else
    inherited HandlePut(ARequest, AResponse);
end;

end.
