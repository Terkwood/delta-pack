#[macro_use]
extern crate serde_derive;
#[macro_use]
extern crate lazy_static;

use actix_web::{error, get, web, App, HttpResponse, HttpServer, Result};
use regex::Regex;
use sled::{Db, IVec, Tree};
use std::path::PathBuf;
use std::sync::Mutex;
use structopt::StructOpt;

#[derive(Serialize, Deserialize, Debug)]
pub struct Delta {
    pub id: u64,
    pub release_version: String,
    pub previous_version: String,
    pub diff_url: String,
    pub diff_b2bsum: String,
    pub expected_pck_b2bsum: String,
}
struct AppState {
    delta_db: Mutex<Db>,
    version_id_tree: Mutex<Tree>,
}

#[derive(Deserialize)]
struct DeltaQuery {
    from_version: String,
}

lazy_static! {
    /// See https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
    static ref RE_SEMVER: Regex = Regex::new(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$").unwrap();
}

#[get("/deltas")]
async fn index(
    data: web::Data<AppState>,
    delta_query: web::Query<DeltaQuery>,
) -> Result<HttpResponse> {
    if RE_SEMVER.is_match(&delta_query.from_version) {
        let db = &data.delta_db.lock().expect("db lock");
        let version_id_lookup = &data.version_id_tree.lock().expect("vit lock");

        match version_id_lookup.get(&delta_query.from_version) {
            Ok(Some(id_bytes)) => Ok(HttpResponse::Ok().json(deltas_from(db, id_bytes)?)),
            Ok(None) => Ok(HttpResponse::NotFound().finish()),
            Err(_) => Ok(HttpResponse::InternalServerError().finish()),
        }
    } else {
        Ok(HttpResponse::BadRequest().finish())
    }
}

/// Starts a web server which can satisfy delta
/// record queries
#[derive(StructOpt, Debug)]
#[structopt(name = "delta-server")]
struct Opts {
    /// Path to the directory for the embedded DB data
    #[structopt(short, long, parse(from_os_str))]
    data_dir: PathBuf,
    #[structopt(short, long, default_value = "127.0.0.1")]
    host: String,
    #[structopt(short, long)]
    port: Option<u16>,
}

const DEFAULT_PORT: u16 = 45819;
#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let opts = Opts::from_args();

    let db = web::Data::new({
        let db = sled::open(&opts.data_dir).expect("open db");
        let vit = db.open_tree(b"version->id lookup").expect("open tree");

        AppState {
            // this directory will be created if it does not exist
            delta_db: Mutex::new(db),
            version_id_tree: Mutex::new(vit),
        }
    });

    let bound = format!("{}:{}", opts.host, opts.port.unwrap_or(DEFAULT_PORT));
    println!("Serving requests on {}", bound);
    HttpServer::new(move || App::new().app_data(db.clone()).service(index))
        .bind(bound)?
        .run()
        .await
}

fn deltas_from(db: &sled::Db, id: IVec) -> Result<Vec<Delta>> {
    let mut out = vec![];
    for v in db.range(id..).skip(1) {
        let delta: Delta = bincode::deserialize(&v.expect("data").1)
            .map_err(|_| error::ErrorInternalServerError("fail"))?;
        out.push(delta)
    }

    Ok(out)
}
