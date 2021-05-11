# cas-api

This project automates performing certain actions with various student services at Lafayette College. Namely, this project integrates with my other project [duo-client](https://git.lyczak.net/del/duo-client), to automate the process of signing into Lafayette's Central Authentication Service (CAS single-sign-on portal). Once CAS has been bypassed, virtually any student-service is accessible. Currently implemented here is some basic functionality that allows fetching upcoming Moodle events (assignments) from Moodle's RPC API.

This project is under heavy development and currently has rather poor code quality. As time permits, I may fix this in the future.

## Usage

This project is meant to be used as a dependency to other projects. However, it can also be used simply as a CLI for fetching Moodle assignments as follows:
```sh
crystal run src/cli-cas.cr
```

`cli-cas.cr` serves as a good example of how to use the API.

## Contributors

- [Delta Lyczak](https://git.lyczak.net/del) - creator and maintainer
