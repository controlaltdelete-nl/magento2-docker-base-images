vcl 4.1;

backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

sub vcl_recv {
    if (req.method == "PURGE") {
        return (purge);
    }

    if (req.method != "GET" &&
        req.method != "HEAD" &&
        req.method != "PUT" &&
        req.method != "POST" &&
        req.method != "TRACE" &&
        req.method != "OPTIONS" &&
        req.method != "DELETE") {
        return (pipe);
    }

    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    if (req.url ~ "\.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$") {
        unset req.http.Cookie;
        return (hash);
    }

    return (hash);
}

sub vcl_backend_response {
    if (beresp.http.content-type ~ "text") {
        set beresp.do_gzip = true;
    }

    if (bereq.url ~ "\.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$") {
        set beresp.ttl = 86400s;
        unset beresp.http.Set-Cookie;
    }
}

sub vcl_deliver {
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
    } else {
        set resp.http.X-Cache = "MISS";
    }
}
