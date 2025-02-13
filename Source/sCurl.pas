{ 
  sCurl.pas
  Copyright (c) 2019 Paul Davidson. All rights reserved.
}


unit sCurl;


  {$MODE OBJFPC}
  {$H+}
  {$IFDEF DARWIN}
  {$LINKLIB 'libcurl.dylib'}
  {$ENDIF}

interface


  uses
    Classes,
    libCurl,
    SysUtils,
    UNIXType;


  type
  
  
    tCurl = class( TObject )
      private
         fCurlp    : pCurl;
         fMutex    : TRTLCriticalSection;
         fStream   : TMemoryStream;
         fUserName : string;
      public
        constructor Create( s : string );
        destructor  Destroy; override;
        function    Get( s : string ) : string;
        function    Get( s : string; a : TStringArray ) : string;
    end;


  var
    fCurl : tCurl;


implementation


  uses
    sConsole,
    sIRC;

  
  function DoWrite( p : pointer; s : size_t; n : size_t; d : pointer) : size_t; cdecl;
  begin
    DoWrite := TStream( d ).write( p^, s * n );
  end;  // DoWrite


  constructor tCurl.Create( s : string );
  begin
    inherited Create;
    fCurlp    := curl_easy_init;
    fStream   := TMemoryStream.Create;
    fUsername := s;
    InitCriticalSection( fMutex );
  end;  // tCurl.Create;
    

  destructor tCurl.Destroy;
  begin
    curl_easy_cleanup( fCurlp );
    fStream.Free;
    DoneCriticalSection( fMutex );
    inherited Destroy;
  end;  // tCurl.Destroy

  
  function tCurl.Get( s : string ) : string;
    // Short version of next Get
  var
    a : TStringArray;
  begin
    setLength( a, 1 );
    a[ 0 ] := '';
    Get := Self.Get( s, a );
  end;  // tCurl.Get

  
  function tCurl.Get( s : string; a : TStringArray ) : string;
    // Send HTTP request and receive content
    // a is dynamic array of custom header strings like 'Custom_header: some_value'
  var
    b : pcurl_sList;
    i : integer;
    j : CURLCode;
    p : PChar;
    t : string;
  begin
    EnterCriticalSection( fMutex );
    p := NIL;
    t := '';
    try
      curl_easy_setopt( fCurlp, CURLOPT_VERBOSE, [ FALSE ] );                        // Turn verbose off
      curl_easy_setopt( fCurlp, CURLOPT_TRANSFER_ENCODING, [ TRUE ] );               // Turn verbose off
      curl_easy_setopt( fCurlp, CURLOPT_RANGE, [ '0-4000' + #00 ] );                 // Turn small range on
      curl_easy_setopt( fCurlp, CURLOPT_FORBID_REUSE, [ TRUE ] );                    // Close socket after use
      curl_easy_setopt( fCurlp, CURLOPT_FOLLOWLOCATION, [ TRUE ] );                  // Follow redirects
      curl_easy_setopt( fCurlp, CURLOPT_MAXFILESIZE, [ 1024 * 500 ] );               // Read maximum 100k in.  This is to eliminate DoS via long headers or content
      curl_easy_setopt( fCurlp, CURLOPT_MAXREDIRS, [ 10 ] );                         // Allow max of 10 reirects to eliminate infinite redirect DoS
      curl_easy_setopt( fCurlp, CURLOPT_CONNECTTIMEOUT, [ 5 ] );                     // Short connect timeout for hang DoS
      curl_easy_setopt( fCurlp, CURLOPT_TIMEOUT, [ 5 ] );                            // Short response timeout for hang Dos
      if length( a ) > 0 then begin                                                  // Check for any more/custom headers
        b := NIL;
        for i := 0 to length( a ) - 1 do b := curl_slist_append( b, pchar( a[ i ] ) );
        curl_easy_setopt( fCurlp, CURLOPT_HTTPHEADER, [ b ] );
      end;
      curl_easy_setopt( fCurlp, CURLOPT_URL, [ pchar( s ) ] );                          // Set URL
      curl_easy_setopt( fCurlp, CURLOPT_WRITEFUNCTION, [ @DoWrite ] );               // Set data transfer function
      curl_easy_setopt( fCurlp, CURLOPT_WRITEDATA, [ pointer( fStream ) ] );         // Set data transfer location
      j := curl_easy_perform( fCurlp );                                              // Go for it!
      if j = CURLE_OK then begin
        fStream.Position := 0;                                                       // Set stream to start
        SetLength( t, fStream.Size );                                                // Set buffer size
        fStream.Read( t[ 1 ], fStream.Size );                                        // Transfer from stream
      end else begin
        p := curl_easy_strerror( j );
        fIRC.Pending := fUserName + '> CURL ' + strPas( p );
      end;
      fStream.Clear;                                                               // Empty stream
      if length( a ) > 0 then  curl_slist_free_all( b );
      curl_easy_reset( fCurlp );                                                     // Reset curl to initial state
    except
      on E : Exception do fCon.Send( 'Curl> ' + E.Message + ' ' + E.ClassName, taBold );
    end;
    Get := t;
    LeaveCriticalSection( fMutex );
  end;  // tCurlGet


end.  // sCurl 
