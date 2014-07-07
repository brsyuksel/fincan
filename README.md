# fincan

a dirty patch for coffee-script, you can compile your coffee files with your utility functions

## install

`npm install fincan` or as globally `npm install -g fincan`

## usage

fincan uses coffee-script codes under vm, this means all parameters at coffee-script compiler are same. just a difference, fincan looking for **.utilities.coffee** or **.utilities.js** file at current work directory. this file contains your utility functions *( currently supported functions are extends, bind, modulo, indexOf )* which must be defined by you.

sample utilities file looks like below:

`.utilities.coffee`

```coffeescript
module.exports =
  extends: "
    function(child, parent) {
      /* my extend function */
      // ...
    }
  "
  # bind:
  # indexOf:
  # modulo:
```

after creating `.utilities.coffee` file compile your coffee codes: `fincan -c target.coffee`