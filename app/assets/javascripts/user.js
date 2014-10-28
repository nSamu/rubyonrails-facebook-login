(function( $ ) {

  window.fbAsyncInit = function() {
    FB.init( {
      appId:   '863608890326822',
      xfbml:   true,
      version: 'v2.1'
    } );
  };

  (function( d, s, id ) {
    var js, fjs = d.getElementsByTagName( s )[0];
    if( d.getElementById( id ) ) {
      return;
    }
    js = d.createElement( s );
    js.id = id;
    js.src = "//connect.facebook.net/en_US/sdk.js";
    fjs.parentNode.insertBefore( js, fjs );
  }( document, 'script', 'facebook-jssdk' ));

  function submit( token ) {
    $( 'input[name=token]', '#user-login' ).val( token );
    $( 'form', '#user-login' ).trigger( 'submit' );
  }

  function exception( message ) {
    var $container = $( '.login-exception', '#user-login' );

    if( message ) $container.html( message );
    $container.stop( true, false ).show( 0 ).animate( {opacity: 1} ).delay( 5000 ).animate( {opacity: 0} ).promise().always( function() {
      $( this ).hide( 0 )
    } );
  }

  $( function() {

    // első exception megjelenítés
    exception();

    // add click event handler for facebook login
    $( 'button[name=login]', '#user-login-form' ).on( 'click', function( event ) {
      event.preventDefault();

      try {

        // check login status
        FB.getLoginStatus( function( response ) {

          // send the login form with access token
          if( response.status == 'connected' ) submit( response.authResponse.accessToken );
          else FB.login( function( response ) { // try login when not already

            if( response.status == 'connected' ) submit( response.authResponse.accessToken );
            else exception( "Sikertelen bejelentkezés!" );
          }, {auth_type: 'rerequest', scope: 'email'} );
        } );

      } catch( e ) {
        exception( "A facebook API még nem aktív!" );
      }
    } );
  } );
})( jQuery );