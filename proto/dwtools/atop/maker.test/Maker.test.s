( function _Maker_test_s_( ) {

'use strict';

if( typeof module !== 'undefined' )
{

  let _ = require( '../../Tools.s' );

  var _ = _global_.wTools;

  _.include( 'wTesting' );

  require( '../maker/Maker.s' )

}

if( typeof module === 'undefined' )
return;

var _ = _global_.wTools;
var Parent = _.Testing;

//

var files =
{
  'test1.cpp' :
  `int  main(int argc, char const *argv[]) {
    /* code */
    return 0;
  }`,

  'test2.cpp' :
  `#include <iostream>

  int  main(int argc, char const *argv[])
  {
    std::cout << "abc";
    return 0;
  }`
}

var basePath;

//

function testDirMake()
{
  basePath = _.path.pathDirTempOpen( _.path.join( __dirname, '../..' ) );

  _.mapOwnKeys( files )
  .forEach( ( name ) =>
  {
    var path = _.path.join( basePath, name );
    _.fileProvider.fileWrite( path, files[ name ] );
  });
}

//

function cleanTestDir()
{
  _.fileProvider.filesDelete( basePath );
}

//

var pre = function pre()
{
  var outPath = this.env.select( 'opt/outPath' );
  logger.log( 'outPath',outPath );
  _.fileProvider.dirMake( outPath );
};

//

var exe = process.platform === `win32` ? `.exe` : ``;



var simplest = function( test )
{
  var opt =
  {
    basePath: basePath,
    outPath : `{{opt/basePath}}/out`,
    outExe : `{{opt/outPath}}/test1${exe}`,
    src : `{{opt/basePath}}/test1.cpp`,

  };

  var recipe =
  [
    {
      name : 'test1',
      after : '{{opt/outExe}}',
      before : [ '{{opt/src}}' ],
      shell : `g++ {{opt/src}} -o {{opt/outExe}}`,
      pre : pre
    }
  ];

  var o =
  {
    opt : opt,
    recipies : recipe,
  };

  var con = new _.Consequence().take( null );

  con.ifNoErrorThen(function()
  {
    test.case = 'simple make';
    debugger
    var con = wMaker( o ).form();
    return test.returnsSingleResource( con );
  })
  .ifNoErrorThen(function()
  {
    var got = _.fileProvider.statResolvedRead( _.path.join( opt.basePath,`out/test1${exe}` ) ) != undefined;
    test.identical( got,true );
  })
  .ifNoErrorThen(function()
  {
    test.case = "try to make obj file ";

    var recipe =
    [
      {
        name : 'test4',
        after : `{{opt/basePath}}/out/test2.o`,
        before : [ `{{opt/basePath}}/test2.cpp` ],
        shell : `g++ -c {{opt/basePath}}/test2.cpp -o {{opt/basePath}}/out/test2.o`,
      }
    ];

    var o =
    {
      opt : opt,
      recipies : recipe,
    };

    var con = wMaker( o ).form();
    return test.returnsSingleResource( con );
  })
  .ifNoErrorThen(function()
  {
    var got = _.fileProvider.statResolvedRead( _.path.join( opt.basePath,`out/test2.o` ) ) != undefined;
    test.identical( got,true );
  });

  return con;
}

//

var recipeRunCheck = function( test )
{
  var file1 = _.path.join( basePath, 'file1');
  var file2 = _.path.join( basePath, 'file2');

  var called = false;
  var pre = function(){ called = true; }

  _.fileProvider.fileWrite
  ({
      filePath : file1,
      data : 'abc',
      sync : 1,
  });
  var con = _.time.out( 1000 );
  con.finally( function( )
  {
    _.fileProvider.fileWrite
    ({
       filePath : file2,
       data : 'bca',
       sync : 1,
    });
  })
  .ifNoErrorThen( function( arg/*aaa*/ )
  {
    test.case = 'after is older then before';
    var recipe =
    [
      {
        name : 'a1',
        after : `${file1}`,
        before : [ `${file2}` ],
        pre : pre
      }
    ];
    var con = wMaker({ recipies : recipe }).form();
    return test.returnsSingleResource( con );
  })
  .ifNoErrorThen( function( arg/*aaa*/ )
  {
    //if no error recipe is done
    test.identical( called , true );
  })
  .ifNoErrorThen( function( arg/*aaa*/ )
  {
    called = false;
    var recipe =
    [
      {
        name : 'a2',
        after : `${file2}`,
        before : [ `${file1}` ],
        pre : pre
      }
    ];
    test.case = 'after is newer then before';
    var con = wMaker({ recipies : recipe }).form();
    return test.returnsSingleResource( con );
  })
  .ifNoErrorThen( function( arg/*aaa*/ )
  {
    test.identical( called, false );
  })
  .ifNoErrorThen( function( arg/*aaa*/ )
  {
    var recipe =
    [
      {
        name : 'a3',
        after : `${file1}`,
        before : [ `${file1}` ],
        pre : pre
      }
    ];
    test.case = 'after == newer';
    var con = wMaker({ recipies : recipe }).form();
    return test.returnsSingleResource( con );
  })
  .ifNoErrorThen( function( arg/*aaa*/ )
  {
    test.identical( called, false );
  });

  return con;
}

//

var targetsAdjust = function( test )
{
  test.case = "check targets dependencies";
  var recipe =
  [
    {
      name : 'first',
      after : `a1`,
      before : [ 'a.cpp' ],
    },
    {
      name : 'second',
      after : [ 'a2' ],
      before : [ 'first','a2.cpp' ],
    }
  ];

  var maker = wMaker({ recipies : recipe, defaultRecipeName : 'second' });
  maker.form();
  recipe = maker.env.tree.recipe;
  var got = [ recipe.first.beforeNodes, recipe.second.beforeNodes ];
  var expected =
  [
    { 'a.cpp' : { kind : 'file', filePath : 'a.cpp' } },
    {
      'first' :
      {
        kind : 'recipe',
        name : 'first',
        before : [ 'a.cpp' ],
        after : [ 'a1' ],
        beforeNodes : { 'a.cpp' : { kind : 'file', filePath : 'a.cpp' } }
      },
      'a2.cpp' : { kind : 'file', filePath : 'a2.cpp' }
    }
  ];

  test.identical( got, expected );

}

//

var targetInvestigateUpToDate = function( test )
{
  var opt =
  {
    basePath: basePath,
  };

  var recipe =
  [
    {
      name : 'test2',
      after : `{{opt/basePath}}`,
      before : [ `{{opt/basePath}}` ],
      opt : opt
    }
  ];

  test.case = "compare two indentical files";
  var maker = wMaker({ opt : opt, recipies : recipe });
  maker.form();
  var t = maker.recipies[ recipe[ 0 ].name ];
  var got = t.upToDate;
  test.identical( got, true );

  test.case = "compare src with output";
  var recipe =
  [
    {
      name : 'test3',
      after : `{{opt/basePath}}/1.o`,
      before : [ `{{opt/basePath}}` ],
      opt : opt
    }
  ];
  var maker = wMaker({ opt : opt, recipies : recipe, defaultRecipeName : 'test3' });
  maker.form();
  var t = maker.recipies[ recipe[ 0 ].name ];
  var got = t.upToDate
  test.identical( got, false );
}

//

var pathsFor = function( test )
{
  test.case = "check if relative paths are generated correctly";
  var maker = wMaker({ recipies : [ { name : 'test', before : [] } ] });
  maker.form();
  var recipe = maker.recipies[ 'test' ];
  var got = recipe.pathsFor( [ '../../../file', '../../../files/test1.cpp', '../../../test2.cpp' ] );
  var currentDir = _.path.realMainDir();
  var expected =
  [
    _.path.resolve( currentDir, '../../../file' ),
    _.path.resolve( currentDir, '../../../files/test1.cpp' ),
    _.path.resolve( currentDir, '../../../test2.cpp' ),
  ];

  test.identical( got, expected );
}

//

var Self =
{

  name : 'Maker',
  silencing : 1,
  enabled : 0, // !!!

  onSuiteBegin : testDirMake,
  onSuiteEnd : cleanTestDir,

  tests :
  {

    simplest : simplest,
    recipeRunCheck : recipeRunCheck,
    targetsAdjust : targetsAdjust,
    targetInvestigateUpToDate : targetInvestigateUpToDate,

    //etc

    pathsFor : pathsFor,

  },

  /* verbose : 1, */

}

//

Self = wTestSuite( Self );
if( typeof module !== 'undefined' && !module.parent )
wTester.test( Self.name );

})();
