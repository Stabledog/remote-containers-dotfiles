
const main = function(infile:string) : boolean {

    process.stdout.write(`Hello world: ${infile}`);
    return true;
};

process.exit( main( process.argv[2] ) ? 0 : 1 );
