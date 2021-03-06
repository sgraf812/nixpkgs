{stdenv, fetchurl, unzip} :

stdenv.mkDerivation {
  name = "httpunit-1.7";
  builder = ./builder.sh;

  src = fetchurl {
    url = mirror://sourceforge/httpunit/httpunit-1.7.zip;
    sha256 = "09gnayqgizd8cjqayvdpkxrc69ipyxawc96aznfrgdhdiwv8l5zf";
  };

  inherit unzip;

  meta = with stdenv.lib; {
    homepage = http://httpunit.sourceforge.net;
    platforms = platforms.unix;
    license = licenses.mit;
  };
}
