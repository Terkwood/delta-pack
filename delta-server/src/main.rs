#[macro_use]
extern crate serde_derive;
#[macro_use]
extern crate lazy_static;

use actix_web::{error, get, post, web, App, HttpResponse, HttpServer, Result};
use futures::{future, StreamExt};
use regex::Regex;
use sled::{Db, IVec, Tree};
use std::path::PathBuf;
use std::sync::{Arc, Mutex};
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
    delta_db: Arc<Mutex<Db>>,
    version_id_tree: Arc<Mutex<Tree>>,
}

#[derive(Deserialize)]
struct DeltaQuery {
    from_version: String,
}

lazy_static! {
    /// See https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
    static ref RE_SEMVER: Regex = Regex::new(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$").unwrap();
}

/// Starts a web server which can satisfy delta
/// record queries
#[derive(StructOpt, Debug)]
#[structopt(name = "delta-server")]
struct Opts {
    /// Path to the directory for the embedded DB data
    #[structopt(short, long, parse(from_os_str))]
    data_dir: PathBuf,
    #[structopt(short, long)]
    host: Option<String>,
    #[structopt(short, long)]
    port: Option<u16>,
    #[structopt(short, long)]
    admin_port: Option<u16>,
}

const MAX_POST_SIZE: usize = 262_144; // max payload size is 256k
#[post("/deltas")]
async fn create(mut payload: web::Payload, _data: web::Data<AppState>) -> Result<HttpResponse> {
    // payload is a stream of Bytes objects
    let mut body = web::BytesMut::new();
    while let Some(chunk) = payload.next().await {
        let chunk = chunk?;
        // limit max size of in-memory payload
        if (body.len() + chunk.len()) > MAX_POST_SIZE {
            return Err(error::ErrorBadRequest("overflow"));
        }
        body.extend_from_slice(&chunk);
    }

    let _delta = serde_json::from_slice::<Delta>(&body)?;

    todo!("write to DB");
    Ok(HttpResponse::Created().json(_delta))
}

#[get("/deltas")]
async fn query(
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

const DEFAULT_PORT: u16 = 45819;
const DEFAULT_ADMIN_PORT: u16 = 37917;
const DEFAULT_HOST: &str = "127.0.0.1";
#[actix_web::main]
async fn main() -> std::io::Result<()> {
    let opts = Opts::from_args();

    let db = Arc::new(Mutex::new(sled::open(&opts.data_dir).expect("open db")));
    let vit = db
        .lock()
        .expect("init vit")
        .open_tree(b"version->id lookup")
        .expect("open tree");

    let version_ids = Arc::new(Mutex::new(vit));

    let db2 = db.clone();
    let v2 = version_ids.clone();

    let app_state = web::Data::new(AppState {
        // this directory will be created if it does not exist
        delta_db: db,
        version_id_tree: version_ids,
    });

    let the_host: &str = &&opts.host.unwrap_or(DEFAULT_HOST.to_string());

    let public_bind = format!("{}:{}", the_host, opts.port.unwrap_or(DEFAULT_PORT));

    let admin_bind = format!(
        "{}:{}",
        the_host,
        opts.admin_port.unwrap_or(DEFAULT_ADMIN_PORT)
    );

    println!(
        "Serving requests on {} (public) and {} (admin)",
        public_bind, admin_bind
    );

    let public = HttpServer::new(move || App::new().app_data(app_state.clone()).service(query))
        .bind(public_bind)?
        .run();

    let admin = HttpServer::new(move || {
        App::new()
            .app_data(AppState {
                delta_db: db2.clone(),
                version_id_tree: v2.clone(),
            })
            .service(create)
    })
    .bind(admin_bind)?
    .run();

    future::try_join(public, admin).await?;

    Ok(())
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
